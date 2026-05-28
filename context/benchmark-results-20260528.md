# Serious Local Benchmark Results - 2026-05-28

Use this as the factual benchmark context for the updated article.

## Run

- Result directory: `results/sequential_generated_serious_20260528_1010`
- Raw measurements: `results/sequential_generated_serious_20260528_1010/measurements.csv`
- Rollup by payload/concurrency/runtime: `results/sequential_generated_serious_20260528_1010/summary-by-cell.csv`
- Peak throughput table: `results/sequential_generated_serious_20260528_1010/peak-throughput-by-payload.csv`
- Pivot table for charts: `results/sequential_generated_serious_20260528_1010/throughput-pivot-by-cell.csv`
- Measurements: 168 rows
- Summarized cells: 84 rows
- Endpoint mode: generated payloads, not giant URL path parameters
- Work factor: 10
- Payload sizes: 7, 128, 2048, 8192 bytes
- Concurrency levels: 1, 6, 12, 24, 48, 96, 192
- Repeats per cell: 2
- Per-cell warmup: 2 seconds
- Per-cell measured duration: 5 seconds
- Services were run sequentially so Go and Java did not compete with each other.

## Environment

- Machine: x86_64 Linux, Intel Xeon W-11855M, 6 cores / 12 threads
- Memory: about 62 GiB RAM
- Go runtime: Go 1.26.3
- Java runtime: Oracle JDK 26.0.1
- Java framework: Helidon SE 4.4.1
- Go server: standard library `net/http`
- Java server: Helidon WebServer LoomServer, virtual-thread-per-task request handling
- Go runtime controls: `GOMAXPROCS=12`, `GOMEMLIMIT=off`
- Java runtime controls: `-XX:ActiveProcessorCount=12 -XX:MaxRAMPercentage=75`
- Request logging: off
- Load generator and service ran on the same host, but only one service ran at a time.
- GraalVM JVM and GraalVM native image were recorded as skipped because `GRAALVM_HOME` and the native executable were not available.

## Important Tuning Discovery

The generated 2 KB Helidon response initially showed a suspicious persistent-connection latency floor around 44-48 ms. That was not application string manipulation. A quick probe showed fresh `curl` requests were fast after warmup, while the Go load driver on persistent HTTP/1.1 connections was slow. Setting Helidon connection options to `tcpNoDelay(true)` removed that delayed-packet behavior. The serious run used `tcpNoDelay=true`.

Both services now set `Content-Length` explicitly for known-size JSON responses. The Go service also runs as a built binary from `scripts/run-go.sh`, not `go run`, and both services report runtime metadata from `/health`.

## Peak Throughput By Payload

These are median requests per second at the best concurrency for each runtime/payload cell.

| Runtime | Payload | Best concurrency | Peak median rps | p95 at peak | p99 at peak |
| --- | ---: | ---: | ---: | ---: | ---: |
| Go stdlib | 7 | 192 | 61,785.28 | 10.22 ms | 16.08 ms |
| Oracle JDK JVM | 7 | 192 | 97,190.01 | 5.92 ms | 9.05 ms |
| Oracle JDK Leyden AOT | 7 | 96 | 74,997.73 | 3.83 ms | 6.52 ms |
| Go stdlib | 128 | 192 | 51,332.43 | 13.10 ms | 19.31 ms |
| Oracle JDK JVM | 128 | 192 | 76,415.12 | 7.65 ms | 12.05 ms |
| Oracle JDK Leyden AOT | 128 | 192 | 74,887.12 | 7.57 ms | 12.15 ms |
| Go stdlib | 2048 | 192 | 16,217.01 | 43.14 ms | 67.93 ms |
| Oracle JDK JVM | 2048 | 96 | 38,373.56 | 5.87 ms | 8.63 ms |
| Oracle JDK Leyden AOT | 2048 | 192 | 34,308.34 | 13.59 ms | 19.55 ms |
| Go stdlib | 8192 | 192 | 6,922.48 | 97.85 ms | 152.07 ms |
| Oracle JDK JVM | 8192 | 192 | 13,427.28 | 28.35 ms | 40.41 ms |
| Oracle JDK Leyden AOT | 8192 | 96 | 13,913.82 | 14.07 ms | 19.55 ms |

## Shape Of The Results

- At the tiny 7-byte payload, Go is a little ahead at concurrency 1, but Oracle JDK catches up and passes it at higher concurrency. At concurrency 192, Oracle JDK JVM reached about 97k rps versus Go at about 62k rps.
- At 128 bytes, Oracle JDK and Leyden AOT are both well ahead at higher concurrency. At concurrency 192, the Java variants were about 75-76k rps versus Go at about 51k rps.
- At 2 KB, the Java lead becomes large. Oracle JDK JVM peaked at about 38k rps and Leyden AOT at about 34k rps, versus Go at about 16k rps.
- At 8 KB, both Java variants were roughly 2x Go at peak throughput in this run.
- Leyden AOT did not simply dominate the JVM. It helped some low-concurrency cells and the 8 KB peak, but regular Oracle JDK JVM was stronger in several steady-state throughput cells.
- All serious-run measurement rows had zero request failures.

## Article Guidance

Do not present this as "Java beats Go." Present it as a measured local result for this particular service, runtime, framework, machine, workload, and load driver. The interesting story is that the first tiny case is close, but the Java/Helidon implementation scaled better in this local multi-core sweep as payload and concurrency grew.

Also include the tuning lesson: before `tcpNoDelay(true)`, Helidon looked terrible for larger responses under persistent HTTP/1.1; after the socket option, it behaved like a serious server. That is a useful reminder that benchmark conclusions can be invalidated by one missed production setting.
