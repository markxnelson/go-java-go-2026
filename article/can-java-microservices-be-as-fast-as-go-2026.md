# Can Java Microservices Be As Fast As Go? A 2026 Benchmark Update

Six years ago, Peter Nagy and I asked a question that was simple enough to be fun and annoying enough to be useful:

Can Java microservices be as fast as Go microservices?

It was not meant to be a language war. Those are usually boring, and worse, they tend to make people less curious. The original question was more practical than that. If you take a small HTTP service, implement it carefully in Go and Java, and then run it on the same hardware, do the results land in the same performance neighborhood?

In 2020, the answer was yes for the small case. The more interesting shape, if I remember the run correctly, was that Java got more competitive as the application and the machine got larger. Small cases were close. Bigger, warmer, more parallel cases were where the JVM started to look less like a liability and more like a machine that had been tuned for exactly this kind of work for a very long time.

That is the part I wanted to revisit.

Not "is Java faster than Go?"

Not "did Go lose?"

Not "did the JVM solve all computer problems and also fold the laundry?"

The better question is:

For this service, on this machine, with current runtimes, what actually happens as we increase payload size and concurrency?

The code and results for this update are in this repository:

```text
/home/mark/redstack/go-java-go-2026
```

## The Baseline

For this run I used:

- Go 1.26.3
- Oracle JDK 26.0.1
- Helidon SE 4.4.1
- Linux on x86_64
- Intel Xeon W-11855M, 6 cores / 12 threads
- About 62 GiB RAM

The Go service uses the standard library `net/http` server. No framework. No middleware stack.

The Java service uses Helidon SE WebServer. Helidon 4 uses virtual threads for request handling, and the service health endpoint confirms that request work is running on virtual threads.

I also prepared the Java side to compare several runtime shapes:

- Oracle JDK JVM
- Oracle JDK with a Leyden AOT cache
- GraalVM JVM
- GraalVM Native Image

For this local run, GraalVM was not installed, and no native image executable was available. The benchmark configuration table records those variants as skipped. The scripts are still there so the GraalVM runs can be added later without changing the table format.

## The Service

Both services expose the same basic endpoints:

```text
GET /health
GET /ready
GET /api/strings/{value}
GET /api/generated/{size}
```

The `strings` endpoint is useful for simple functional checks. The generated endpoint is the one I used for the benchmark matrix.

That distinction matters.

In an early run I tested a 2 KB input by putting a 2 KB string directly in the URL path. That mostly told me how each router handled a silly path parameter. Interesting, maybe, but not the thing I wanted to measure. The serious run uses `/api/generated/{size}` so the URL stays small and the application generates the requested input size inside the handler.

Each request does the same small unit of work:

- uppercase the input
- lowercase the input
- reverse the input
- compute a CRC32 hash
- repeat extra CRC work according to `WORK_FACTOR`
- return JSON with the result and runtime metadata

For the serious run, `WORK_FACTOR=10`. Request logging was off.

This is still a small synthetic service. It is not a shopping cart, a fraud system, or a payments API. It has no database, no TLS, no queue, no JSON parser on the inbound side, and no remote dependency. That is intentional. The point is to make the hot path small enough that runtime and server behavior are visible.

## The Benchmark Shape

The benchmark runner starts one service, runs the full matrix, stops it, and then starts the next service. Go and Java do not run at the same time, so they are not competing with each other for CPU or memory.

The serious run used:

```text
payload sizes:      7, 128, 2048, 8192 bytes
concurrency levels: 1, 6, 12, 24, 48, 96, 192
repeats per cell:   2
warmup per cell:    2 seconds
measurement window: 5 seconds
work factor:        10
```

The runtime settings were explicit:

```text
Go:
  GOMAXPROCS=12
  GOMEMLIMIT=off

Java:
  -XX:ActiveProcessorCount=12
  -XX:MaxRAMPercentage=75
```

The results are saved here:

```text
results/sequential_generated_serious_20260528_1010/
```

The useful tables are:

```text
configurations.csv
measurements.csv
summary-by-cell.csv
peak-throughput-by-payload.csv
throughput-pivot-by-cell.csv
```

That last file is meant for charts. It pivots median throughput by payload and concurrency, with one column per runtime variant.

## The Boring Tuning Detail That Changed The Java Result

Before the serious run, I hit a strange result.

The Helidon service looked fine for tiny responses, but larger generated responses had a suspicious latency floor around 44-48 ms when the Go load driver reused persistent HTTP/1.1 connections. A fresh `curl` request did not show the same behavior after warmup. That smelled less like application code and more like packet behavior.

The fix was:

```java
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
```

After setting `tcpNoDelay(true)`, the 2 KB persistent-connection case moved from "obviously broken benchmark" to "serious server." That is exactly why these tests are worth running before writing the article. A single missed production setting can turn into a confident but wrong conclusion.

Both services also set `Content-Length` explicitly for known-size JSON responses.

## Peak Throughput

Here is the peak median throughput for each runtime and payload size. "Peak" means the best median requests per second across the tested concurrency levels.

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

That is the interesting version of the story.

At the smallest payload, Go is competitive and wins the single-concurrency cell. But as concurrency rises, the Oracle JDK JVM run pulls ahead. At 192 concurrent workers and a 7-byte generated payload, the JVM run reaches about 97k requests/sec, compared with about 62k for Go.

At 128 bytes, the Java variants are ahead at higher concurrency. At 192 concurrent workers, the Oracle JDK JVM run lands around 76k requests/sec. Leyden AOT is close behind at about 75k. Go is around 51k.

At 2 KB, the gap is much larger. Go peaks at about 16k requests/sec. Oracle JDK JVM peaks at about 38k. Leyden AOT peaks at about 34k.

At 8 KB, both Java shapes are roughly twice the Go throughput in this run. Oracle JDK JVM peaks at about 13.4k requests/sec. Leyden AOT peaks at about 13.9k. Go peaks at about 6.9k.

No measured row in the serious run had request failures.

## Throughput Across Concurrency

Peak numbers are useful, but they can hide the shape. Here are the median throughput values from the pivot table.

| Payload | Concurrency | Go stdlib rps | Oracle JDK JVM rps | Oracle JDK Leyden AOT rps |
| ---: | ---: | ---: | ---: | ---: |
| 7 | 1 | 4,867.86 | 3,978.52 | 4,831.73 |
| 7 | 12 | 21,024.46 | 20,901.05 | 25,995.61 |
| 7 | 48 | 49,563.99 | 54,187.83 | 60,238.88 |
| 7 | 96 | 58,048.83 | 72,504.43 | 74,997.73 |
| 7 | 192 | 61,785.28 | 97,190.01 | 72,389.83 |
| 128 | 1 | 4,443.95 | 4,250.15 | 4,703.74 |
| 128 | 12 | 21,771.10 | 28,461.30 | 28,683.03 |
| 128 | 48 | 31,602.71 | 70,080.90 | 57,867.88 |
| 128 | 96 | 39,423.87 | 74,156.25 | 69,650.68 |
| 128 | 192 | 51,332.43 | 76,415.12 | 74,887.12 |
| 2048 | 1 | 3,164.74 | 3,577.10 | 2,725.09 |
| 2048 | 12 | 3,144.01 | 21,796.06 | 13,528.76 |
| 2048 | 48 | 9,715.43 | 31,452.15 | 27,772.60 |
| 2048 | 96 | 13,241.83 | 38,373.56 | 22,502.28 |
| 2048 | 192 | 16,217.01 | 36,964.76 | 34,308.34 |
| 8192 | 1 | 1,881.05 | 2,035.54 | 1,971.32 |
| 8192 | 12 | 3,790.17 | 9,664.95 | 10,904.42 |
| 8192 | 48 | 5,042.88 | 12,594.97 | 11,638.42 |
| 8192 | 96 | 6,050.80 | 11,167.28 | 13,913.82 |
| 8192 | 192 | 6,922.48 | 13,427.28 | 13,038.49 |

This is closer to what I hoped we would see: not a slogan, but a curve.

For the smallest case, the services are in the same range until the very high-concurrency end, where the JVM run opens a clear lead. As the generated payload grows, Java's advantage shows up earlier and more strongly.

That does not mean "Java is faster than Go." It means this Java implementation, on this JDK, with Helidon virtual-thread request handling and the right socket setting, scaled better than this Go implementation in this local matrix.

That sentence has a lot of nouns in it. It needs all of them.

## What Leyden AOT Did

Leyden AOT did not simply make everything faster.

It was strong in some cells. It had the best 8 KB peak in this run: about 13.9k requests/sec at concurrency 96, with p95 around 14 ms and p99 around 20 ms. It was also very competitive at 128 bytes.

But the regular Oracle JDK JVM run won several steady-state cells, including the highest 7-byte peak and the strongest 2 KB peak.

That is not disappointing. It is useful. Leyden AOT is not a magic "make benchmark bigger" switch. It changes startup, warmup, and runtime behavior in ways that need to be measured against the workload you actually care about.

For this article, the honest summary is:

The Oracle JDK JVM result was strongest overall in the steady-state throughput matrix. Leyden AOT was close in many cells and best in the 8 KB peak cell. Startup and footprint deserve their own pass.

## What About GraalVM Native Image?

I wanted to include it.

The harness has slots for:

```text
graalvm-jvm
graalvm-native
```

But this machine did not have `GRAALVM_HOME/bin/java`, and the native image executable was not present. The run records both variants as skipped in `configurations.csv`.

That is better than pretending. Native Image is an important Java deployment shape, especially for startup time and footprint. It should be tested here. It just was not tested in this run.

## What The Results Mean

For this benchmark shape, Java was not merely "as fast as Go." Once the test moved beyond the smallest case, the Java implementation often scaled better.

That is the interesting result.

It is also not a universal result. I would not take these numbers and make a company-wide language policy. Please do not do that. That is how benchmark articles become office folklore, and office folklore is where nuance goes to quietly retire.

What I would take from this run is more practical:

Go remains excellent for small services. The implementation is compact. The toolchain is simple. The standard HTTP server is capable. The single-binary deployment story is still very attractive.

Modern Java is also excellent for small services, and it has a very different set of strengths. The JVM has a mature optimizer, rich observability tools, excellent GC engineering, and now a mainstream virtual-thread model that makes blocking server code feel much less expensive than it used to.

Helidon SE keeps the Java side small enough that this comparison is not "minimal Go versus enormous Java framework." It is a compact Java service using a compact Java server.

The old easy argument was that Go is the obvious choice for small network services because Java is too heavy.

That argument does not survive this run.

## What I Would Measure Next

Throughput is only one part of the story.

The next pass should add:

- startup time
- RSS and heap usage
- CPU utilization
- GC logs
- Java Flight Recorder
- async-profiler
- longer runs
- more repeats per cell
- isolated load generator host
- container limits
- TLS
- request logging on and off
- GraalVM JVM
- GraalVM Native Image
- Spring Boot
- at least one real dependency, such as a database call

I would also keep the `tcpNoDelay` lesson in the benchmark checklist. It is not glamorous, but neither is being wrong by 40 milliseconds.

## How To Reproduce This Run

Build the Java service:

```bash
cd helidon-service
JAVA_HOME=/home/mark/jdk-26.0.1 \
PATH=/home/mark/jdk-26.0.1/bin:/home/mark/apache-maven-3.9.12/bin:$PATH \
mvn -B -DskipTests package
```

Run the sequential matrix:

```bash
RESULTS_DIR=/home/mark/redstack/go-java-go-2026/results/sequential_generated_$(date +%Y%m%d_%H%M%S) \
GO_PORT=25081 \
JAVA_PORT=25082 \
CONCURRENCY_LEVELS="1 6 12 24 48 96 192" \
PAYLOAD_SIZES="7 128 2048 8192" \
REPEATS=2 \
DURATION=5s \
WARMUP_DURATION=2s \
JAVA_VARIANTS="oracle-jdk-jvm oracle-jdk-leyden-aot graalvm-jvm graalvm-native" \
WORK_FACTOR=10 \
ENDPOINT_MODE=generated \
scripts/run-sequential-matrix.sh
```

The runner writes the raw and summarized tables automatically.

## The Bit I Still Believe

The original article did not settle the question forever. It was never going to.

Performance is not just a property of a language.

It is also a property of:

- hardware shape
- runtime version
- framework choices
- warmup
- logging
- serialization
- socket options
- container limits
- GC behavior
- load-driver design
- measurement duration
- noisy neighbors
- the parts of the service that are not in your benchmark

That was true in 2020, and it is still true in 2026.

So, can Java microservices be as fast as Go?

For this service, on this machine, with these versions, yes. And as the payload and concurrency grew, the Java implementation was often faster.

That is not a trophy. It is a measurement.

The useful next question is not "which language won?"

It is "which runtime shape do you want to operate, observe, tune, deploy, and live with in production?"

That is a better question. It gives you something to measure, something to improve, and, on a good day, something worth changing your mind about.
