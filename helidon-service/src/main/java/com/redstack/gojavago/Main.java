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

    private Main() {
    }

    public static void main(String[] args) {
        int port = Integer.parseInt(env("PORT", "8080"));
        boolean logRequests = Boolean.parseBoolean(env("LOG_REQUESTS", "false"));

        WebServer server = WebServer.builder()
                .port(port)
                .routing(routing -> routing
                        .get("/health", (req, res) -> health(res))
                        .get("/ready", (req, res) -> ready(res))
                        .get("/api/strings/{value}", (req, res) -> strings(req, res, logRequests)))
                .build()
                .start();

        LOGGER.info(() -> "helidon service listening on http://localhost:" + server.port());
    }

    private static void health(ServerResponse response) {
        json(response, "{\"status\":\"UP\",\"runtime\":\"" + jsonEscape(runtimeVersion()) + "\"}");
    }

    private static void ready(ServerResponse response) {
        json(response, "{\"status\":\"READY\"}");
    }

    private static void strings(ServerRequest request, ServerResponse response, boolean logRequests) {
        Instant start = Instant.now();
        String value = request.path().pathParameters().first("value").orElse("");
        String body = transform(value, logRequests);
        if (logRequests) {
            Duration elapsed = Duration.between(start, Instant.now());
            LOGGER.info(() -> "path=" + request.path().path() + " input=\"" + value + "\" elapsed=" + elapsed);
        }
        json(response, body);
    }

    private static String transform(String value, boolean logEnabled) {
        return "{"
                + "\"input\":\"" + jsonEscape(value) + "\","
                + "\"uppercase\":\"" + jsonEscape(value.toUpperCase(Locale.ROOT)) + "\","
                + "\"lowercase\":\"" + jsonEscape(value.toLowerCase(Locale.ROOT)) + "\","
                + "\"reversed\":\"" + jsonEscape(reverse(value)) + "\","
                + "\"hash\":" + stableHash(value) + ","
                + "\"runtime\":\"" + jsonEscape(runtimeVersion()) + "\","
                + "\"language\":\"java\","
                + "\"logEnabled\":" + logEnabled
                + "}";
    }

    private static void json(ServerResponse response, String body) {
        response.header(HeaderNames.CONTENT_TYPE, "application/json");
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

    private static String runtimeVersion() {
        return ManagementFactory.getRuntimeMXBean().getVmName() + " " + Runtime.version();
    }

    private static String env(String name, String fallback) {
        String value = System.getenv(name);
        return value == null || value.isBlank() ? fallback : value.trim();
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
}

