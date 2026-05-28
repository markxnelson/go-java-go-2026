package com.redstack.gojavago;

import java.lang.management.ManagementFactory;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.Locale;
import java.util.logging.Logger;
import java.util.zip.CRC32;

import io.helidon.http.HeaderNames;
import io.helidon.webserver.WebServer;
import io.helidon.webserver.http.ServerRequest;
import io.helidon.webserver.http.ServerResponse;

public final class Main {
    private static final Logger LOGGER = Logger.getLogger(Main.class.getName());
    private static final String RUNTIME_VERSION = runtimeVersion();
    private static final RuntimeInfo RUNTIME_INFO = runtimeInfo();

    private Main() {
    }

    public static void main(String[] args) {
        int port = Integer.parseInt(env("PORT", "8080"));
        boolean logRequests = Boolean.parseBoolean(env("LOG_REQUESTS", "false"));
        int workFactor = positiveInt(env("WORK_FACTOR", "1"), 1);

        WebServer server = WebServer.builder()
                .port(port)
                .connectionOptions(socket -> socket.tcpNoDelay(true))
                .routing(routing -> routing
                        .get("/health", (req, res) -> health(res))
                        .get("/ready", (req, res) -> ready(res))
                        .get("/api/strings/{value}", (req, res) -> strings(req, res, logRequests, workFactor))
                        .get("/api/generated/{size}", (req, res) -> generated(req, res, logRequests, workFactor)))
                .build()
                .start();

        LOGGER.info(() -> "helidon service listening on http://localhost:" + server.port()
                + " processors=" + RUNTIME_INFO.availableProcessors()
                + " maxMemoryBytes=" + RUNTIME_INFO.maxMemoryBytes()
                + " serverModel=\"" + RUNTIME_INFO.serverModel() + "\""
                + " workFactor=" + workFactor);
    }

    private static void health(ServerResponse response) {
        json(response, "{"
                + "\"status\":\"UP\","
                + "\"runtime\":\"" + jsonEscape(RUNTIME_VERSION) + "\","
                + "\"language\":\"java\","
                + "\"runtimeInfo\":" + runtimeInfoJson(Thread.currentThread().isVirtual())
                + "}");
    }

    private static void ready(ServerResponse response) {
        json(response, "{\"status\":\"READY\"}");
    }

    private static void strings(ServerRequest request, ServerResponse response, boolean logRequests, int workFactor) {
        Instant start = Instant.now();
        String value = request.path().pathParameters().first("value").orElse("");
        boolean virtualThread = Thread.currentThread().isVirtual();
        String body = transform(value, logRequests, workFactor, virtualThread);
        if (logRequests) {
            Duration elapsed = Duration.between(start, Instant.now());
            LOGGER.info(() -> "path=" + request.path().path() + " input=\"" + value + "\" elapsed=" + elapsed);
        }
        json(response, body);
    }

    private static void generated(ServerRequest request, ServerResponse response, boolean logRequests, int workFactor) {
        Instant start = Instant.now();
        int size = pathInt(request, "size", "Helidon".length());
        String value = generatedValue(size);
        boolean virtualThread = Thread.currentThread().isVirtual();
        String body = transform(value, logRequests, workFactor, virtualThread);
        if (logRequests) {
            Duration elapsed = Duration.between(start, Instant.now());
            LOGGER.info(() -> "path=" + request.path().path() + " size=" + size + " elapsed=" + elapsed);
        }
        json(response, body);
    }

    private static String transform(String value, boolean logEnabled, int workFactor, boolean virtualThread) {
        String uppercase = value.toUpperCase(Locale.ROOT);
        String lowercase = value.toLowerCase(Locale.ROOT);
        String reversed = reverse(value);
        return "{"
                + "\"input\":\"" + jsonEscape(value) + "\","
                + "\"uppercase\":\"" + jsonEscape(uppercase) + "\","
                + "\"lowercase\":\"" + jsonEscape(lowercase) + "\","
                + "\"reversed\":\"" + jsonEscape(reversed) + "\","
                + "\"hash\":" + stableHash(value) + ","
                + "\"workFactor\":" + workFactor + ","
                + "\"workScore\":" + extraWork(uppercase, lowercase, reversed, workFactor) + ","
                + "\"runtime\":\"" + jsonEscape(RUNTIME_VERSION) + "\","
                + "\"language\":\"java\","
                + "\"logEnabled\":" + logEnabled + ","
                + "\"runtimeInfo\":" + runtimeInfoJson(virtualThread)
                + "}";
    }

    private static void json(ServerResponse response, String body) {
        response.header(HeaderNames.CONTENT_TYPE, "application/json");
        response.header(HeaderNames.CONTENT_LENGTH, String.valueOf(body.getBytes(StandardCharsets.UTF_8).length));
        response.send(body);
    }

    private static String reverse(String value) {
        int[] codePoints = value.codePoints().toArray();
        StringBuilder builder = new StringBuilder(value.length());
        for (int i = codePoints.length - 1; i >= 0; i--) {
            builder.appendCodePoint(codePoints[i]);
        }
        return builder.toString();
    }

    private static long stableHash(String value) {
        CRC32 crc = new CRC32();
        crc.update(value.getBytes(StandardCharsets.UTF_8));
        return crc.getValue();
    }

    private static long extraWork(String uppercase, String lowercase, String reversed, int workFactor) {
        byte[] upperBytes = uppercase.getBytes(StandardCharsets.UTF_8);
        byte[] lowerBytes = lowercase.getBytes(StandardCharsets.UTF_8);
        byte[] reversedBytes = reversed.getBytes(StandardCharsets.UTF_8);
        CRC32 crc = new CRC32();
        for (int i = 0; i < workFactor; i++) {
            crc.update(upperBytes);
            crc.update(lowerBytes);
            crc.update(reversedBytes);
        }
        return crc.getValue();
    }

    private static int pathInt(ServerRequest request, String name, int fallback) {
        String value = request.path().pathParameters().first(name).orElse("");
        try {
            int parsed = Integer.parseInt(value.trim());
            return parsed > 0 && parsed <= 65536 ? parsed : fallback;
        } catch (NumberFormatException ex) {
            return fallback;
        }
    }

    private static String generatedValue(int size) {
        if (size == "Helidon".length()) {
            return "Helidon";
        }
        return "x".repeat(size);
    }

    private static String runtimeVersion() {
        return ManagementFactory.getRuntimeMXBean().getVmName() + " " + Runtime.version();
    }

    private static RuntimeInfo runtimeInfo() {
        Runtime runtime = Runtime.getRuntime();
        return new RuntimeInfo(
                runtime.availableProcessors(),
                runtime.maxMemory(),
                "Helidon WebServer LoomServer virtual-thread-per-task, tcpNoDelay=true");
    }

    private static String runtimeInfoJson(boolean virtualThread) {
        return "{"
                + "\"availableProcessors\":" + RUNTIME_INFO.availableProcessors() + ","
                + "\"maxMemoryBytes\":" + RUNTIME_INFO.maxMemoryBytes() + ","
                + "\"serverModel\":\"" + jsonEscape(RUNTIME_INFO.serverModel()) + "\","
                + "\"requestThreadVirtual\":" + virtualThread
                + "}";
    }

    private static String env(String name, String fallback) {
        String value = System.getenv(name);
        return value == null || value.isBlank() ? fallback : value.trim();
    }

    private static int positiveInt(String value, int fallback) {
        try {
            int parsed = Integer.parseInt(value.trim());
            return parsed > 0 ? parsed : fallback;
        } catch (NumberFormatException ex) {
            return fallback;
        }
    }

    private static String jsonEscape(String value) {
        StringBuilder builder = new StringBuilder(value.length() + 16);
        for (int i = 0; i < value.length(); i++) {
            char ch = value.charAt(i);
            switch (ch) {
                case '"' -> builder.append("\\\"");
                case '\\' -> builder.append("\\\\");
                case '\b' -> builder.append("\\b");
                case '\f' -> builder.append("\\f");
                case '\n' -> builder.append("\\n");
                case '\r' -> builder.append("\\r");
                case '\t' -> builder.append("\\t");
                default -> {
                    if (ch < 0x20) {
                        builder.append(String.format("\\u%04x", (int) ch));
                    } else {
                        builder.append(ch);
                    }
                }
            }
        }
        return builder.toString();
    }

    private record RuntimeInfo(int availableProcessors, long maxMemoryBytes, String serverModel) {
    }
}
