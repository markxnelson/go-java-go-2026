# Companion Code Excerpts

These excerpts summarize the companion code under `/home/mark/redstack/go-java-go-2026`.

## Go Service

File: `go-service/cmd/server/main.go`

- Uses standard library `net/http`.
- Reads `PORT`, default `8080`.
- Reads `LOG_REQUESTS`, default `false`.
- Defines:
  - `GET /health`
  - `GET /ready`
  - `GET /api/strings/{value}`
- Transforms the input into uppercase, lowercase, reversed text, and CRC32 hash.
- Reports `runtime.Version()` in responses.

Representative handler:

```go
mux.HandleFunc("GET /api/strings/{value}", func(w http.ResponseWriter, r *http.Request) {
    start := time.Now()
    value := r.PathValue("value")
    result := transform(value, logRequests)
    if logRequests {
        log.Printf("path=%s input=%q elapsed=%s", r.URL.Path, value, time.Since(start))
    }
    writeJSON(w, result)
})
```

## Helidon Service

File: `helidon-service/src/main/java/com/redstack/gojavago/Main.java`

- Uses Helidon SE WebServer.
- Parent artifact: `io.helidon.applications:helidon-se:4.4.1`.
- Maven compiler release: `26`.
- Reads `PORT`, default `8080`.
- Reads `LOG_REQUESTS`, default `false`.
- Defines the same three endpoints as the Go service.
- Transforms the input into uppercase, lowercase, reversed text, and CRC32 hash.
- Reports JVM name and `Runtime.version()` in responses.

Representative routing:

```java
WebServer server = WebServer.builder()
        .port(port)
        .routing(routing -> routing
                .get("/health", (req, res) -> health(res))
                .get("/ready", (req, res) -> ready(res))
                .get("/api/strings/{value}", (req, res) -> strings(req, res, logRequests)))
        .build()
        .start();
```

## Load Driver

File: `bench/cmd/load/main.go`

- Uses Go standard library HTTP client.
- Accepts:
  - `-url`
  - `-concurrency`
  - `-requests`
  - `-warmup`
- Prints:
  - requests
  - failures
  - first failure, if any
  - elapsed
  - requests per second
  - p50, p95, p99

The load driver is intentionally small. It is useful for a reproducible article demo, but the article should still tell readers to use a stronger tool and more disciplined methodology for serious benchmarking.

