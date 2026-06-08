# Go Java Go 2026

Companion code for an updated version of "Can Java microservices be as fast as Go?"

The comparison is intentionally small and boring:

- Go service: standard library `net/http`
- Java service: Helidon SE WebServer
- Workload: generated string manipulation plus stable hash and configurable extra CRC work
- Endpoints: `/health`, `/ready`, `/api/strings/{value}`, `/api/generated/{size}`
- Optional per-request logging: `LOG_REQUESTS=true`

The baseline versions for the 2026 article are:

- Go 1.26.3
- Oracle JDK 26.0.1
- Helidon 4.4.1

The Java rows are intentionally recorded as separate runtime shapes for the regular Oracle JDK JVM and Oracle JDK with a Leyden AOT cache. The code is plain Java and does not depend on preview language features.

## Layout

- `go-service/` - Go implementation
- `helidon-service/` - Java/Helidon SE implementation
- `bench/` - small Go load driver
- `scripts/` - repeatable local run helpers
- `results/` - benchmark output and summary CSVs

## Run The Go Service

```bash
scripts/run-go.sh
```

Use a different port:

```bash
PORT=8081 scripts/run-go.sh
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
curl -s http://localhost:8080/api/generated/2048
```

## Load Test

The load driver is deliberately small so the article can explain it in a few lines. It is not a replacement for wrk, k6, JMeter, async-profiler, JFR, or real production telemetry.

```bash
cd bench
go run ./cmd/load -url http://localhost:8080/api/generated/128 -concurrency 100 -duration 10s -warmup-duration 10s
```

It prints request count, failures, elapsed time, requests per second, and latency percentiles.

## Reproduce The Sequential Matrix

The sequential benchmark starts one service, runs the matrix, stops it, and then starts the next service. This avoids measuring Go and Java while they compete for the same machine.

```bash
RESULTS_DIR=results/sequential_generated_$(date +%Y%m%d_%H%M%S) \
GO_PORT=25081 \
JAVA_PORT=25082 \
CONCURRENCY_LEVELS="1 6 12 24 48 96 192" \
PAYLOAD_SIZES="7 128 2048 8192" \
REPEATS=2 \
DURATION=5s \
WARMUP_DURATION=10s \
SERVICE_WARMUP_DURATION=10s \
JAVA_VARIANTS="oracle-jdk-jvm oracle-jdk-leyden-aot" \
WORK_FACTOR=10 \
ENDPOINT_MODE=generated \
scripts/run-sequential-matrix.sh
```

Each run writes:

- `configurations.csv`
- `measurements.csv`
- `summary-by-cell.csv`
- `peak-throughput-by-payload.csv`
- `throughput-pivot-by-cell.csv`

The Go/Oracle JDK run used in the article is under `results/sequential_generated_serious_20260607_165332/`.
