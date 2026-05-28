# Go Java Go 2026

Companion code for an updated version of "Can Java microservices be as fast as Go?"

The comparison is intentionally small and boring:

- Go service: standard library `net/http`
- Java service: Helidon SE WebServer
- Workload: short string manipulation plus a stable hash
- Endpoints: `/health`, `/ready`, `/api/strings/{value}`
- Optional per-request logging: `LOG_REQUESTS=true`

The baseline versions for the 2026 article are:

- Go 1.26.3
- Oracle JDK 26.0.1
- Helidon 4.4.1

JDK 25 is the latest Java LTS line at the time this workspace was prepared, so the code is plain Java and does not depend on preview language features.

## Layout

- `go-service/` - Go implementation
- `helidon-service/` - Java/Helidon SE implementation
- `bench/` - small Go load driver
- `article/` - article draft output
- `scripts/` - repeatable local run helpers
- `context/` - article-crew inputs and source notes

The updated article is in `article/can-java-microservices-be-as-fast-as-go-2026.md`.

## Run The Go Service

```bash
cd go-service
go run ./cmd/server
```

Use a different port:

```bash
PORT=8081 go run ./cmd/server
```

## Run The Helidon Service

With JDK 26 installed:

```bash
cd helidon-service
mvn package
java -jar target/go-java-go-helidon.jar
```

Use a different port:

```bash
PORT=8082 java -jar target/go-java-go-helidon.jar
```

## Smoke Test

```bash
curl -s http://localhost:8080/health
curl -s http://localhost:8080/api/strings/Helidon
```

## Load Test

The load driver is deliberately small so the article can explain it in a few lines. It is not a replacement for wrk, k6, JMeter, async-profiler, JFR, or real production telemetry.

```bash
cd bench
go run ./cmd/load -url http://localhost:8080/api/strings/Helidon -concurrency 100 -requests 100000 -warmup 1000
```

It prints request count, failures, elapsed time, requests per second, and latency percentiles.

## Reproduce A Local Comparison

Run each service in one terminal, then run the load driver from another terminal:

```bash
scripts/compare-local.sh
```

The script writes JSON-ish text result files under `results/`.
