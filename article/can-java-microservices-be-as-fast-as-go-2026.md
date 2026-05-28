# Can Java Microservices Be As Fast As Go? A 2026 Update

In November 2020, Peter Nagy and I asked a question that was simple enough to be fun and annoying enough to be useful: can Java microservices be as fast as Go microservices?

It was not a language war. At least, it was not meant to be one. The original article used a deliberately small service, kept the code path short, and then looked at what happened as the hardware, logging, JVM warmup, native image packaging, and Kubernetes deployment shape changed.

That is still the useful question in 2026.

Not "is Java faster than Go?" Not "has Go been defeated?" Not "did the JVM finally solve everything?" The better question is smaller and more practical:

Given a specific service, a specific runtime, a specific framework, and a specific environment, are Java and Go in the same performance conversation?

For this update I used current baselines: Go 1.26.3, Oracle JDK 26.0.1, and Helidon SE 4.4.1. JDK 25.0.3 is the current JDK 25 LTS download line, so think of JDK 26 here as the latest feature-release baseline rather than the conservative LTS production default.

The code that goes with this article is in this repository:

```text
/home/mark/redstack/go-java-go-2026
```

## What Changed Since 2020

The short version is that both ecosystems moved.

Go is still Go in the ways people tend to like: a compact toolchain, quick builds, a standard library that can carry a small HTTP service without much ceremony, and a runtime model that makes concurrency feel natural. Since the earlier article, Go has also added generics, and the module/tooling story is ordinary now in the best sense of that word. It is not a novelty; it is just how Go projects work.

Java changed too, and this is the part that old arguments often miss. The Java we were using in that first comparison was based on JDK 11. The Java we can use now has years of JVM, GC, container, startup, and framework work behind it. Virtual threads are no longer a lab curiosity; they were finalized in Java 21 and are now part of the normal Java concurrency conversation. They do not magically make CPU-bound code faster, and they are not the same thing as goroutines, but they do change the cost model for many blocking server workloads.

The framework story changed as well. For this rerun I used Helidon SE because it keeps the Java side compact. I did not want the article to turn into "tiny Go service versus large enterprise Java stack." A Spring Boot comparison would also be useful, and frankly more familiar to many Java teams, but it would answer a different question.

## The New Harness

The new harness is intentionally boring.

There are two services:

```text
go-service/
helidon-service/
```

There is also a small load driver:

```text
bench/
```

Both services expose the same endpoints:

```text
GET /health
GET /ready
GET /api/strings/{value}
```

The string endpoint does a little bit of work:

- uppercase
- lowercase
- reverse
- CRC32 hash

It also reports the runtime and whether request logging is enabled. That last bit matters. In the original article, logging was often the real bottleneck. That is not surprising, but it is the kind of boring operational fact that ruins tidy benchmark stories.

Request logging is off by default in this version. You can turn it on in either service:

```bash
LOG_REQUESTS=true
```

## The Go Service

The Go service uses the standard library `net/http` package. No framework. No middleware stack. No hidden dependency graph.

The interesting route is compact:

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

That is one of Go's strengths. For small HTTP services, you can get a lot done with the platform you already have.

Run it like this:

```bash
cd go-service
go run ./cmd/server
```

Or put it on a different port:

```bash
PORT=8081 go run ./cmd/server
```

## The Helidon Service

The Java version uses Helidon SE WebServer. The Maven parent is pinned to `io.helidon.applications:helidon-se:4.4.1`, and the compiler release is set to 26.

The route setup is deliberately parallel to the Go version:

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

Build and run it with JDK 26:

```bash
cd helidon-service
mvn package
java -jar target/go-java-go-helidon.jar
```

Or use a different port:

```bash
PORT=8082 java -jar target/go-java-go-helidon.jar
```

## Check The Services

Start either service, then try:

```bash
curl -s http://localhost:8080/health
curl -s http://localhost:8080/api/strings/Helidon
```

For `Helidon`, both services should agree on the important values:

```text
uppercase: HELIDON
lowercase: helidon
reversed: nodileH
hash: 2951479431
```

That proves the harness is doing the same functional work. It does not prove a performance result. A smoke test is a seatbelt click, not a lap time.

## Run A Local Comparison

Run the Go service on one port and the Helidon service on another. Then run:

```bash
CONCURRENCY=100 REQUESTS=100000 WARMUP=5000 GO_PORT=8081 JAVA_PORT=8082 scripts/compare-local.sh
```

The script writes results under `results/` and records basic environment output. The load driver prints:

- requests
- failures
- elapsed time
- requests per second
- p50
- p95
- p99

This is a small driver, not a replacement for `wrk`, `k6`, JMeter, Java Flight Recorder, async-profiler, production telemetry, or a real benchmark plan. It is here so the article has a runnable baseline and so you can start changing one thing at a time.

## My Local Run

I ran three local passes on the same machine with request logging disabled.

The environment was:

- Linux on x86_64
- Intel Xeon W-11855M, 6 cores / 12 threads
- 62 GiB RAM
- Go 1.26.3
- Oracle JDK 26.0.1
- Helidon SE 4.4.1
- client and server on the same host
- no containers
- no CPU pinning
- no JVM tuning flags

Here are the three measured passes.

```text
Run 1
Go:     27,261.74 requests/sec, p50 2.113 ms, p95 8.820 ms, p99 19.874 ms
Helidon:21,144.58 requests/sec, p50 3.230 ms, p95 11.458 ms, p99 18.150 ms

Run 2
Go:     24,278.25 requests/sec, p50 2.352 ms, p95 10.153 ms, p99 22.415 ms
Helidon:25,450.79 requests/sec, p50 2.295 ms, p95 8.302 ms, p99 18.879 ms

Run 3
Go:     25,954.01 requests/sec, p50 2.198 ms, p95 9.603 ms, p99 17.850 ms
Helidon:26,440.44 requests/sec, p50 2.200 ms, p95 8.671 ms, p99 16.800 ms
```

Average throughput across those three passes was about 25.8k requests/sec for Go and 24.3k requests/sec for Helidon.

That is the interesting part: not that one language wins, but that the numbers are close enough that a slogan is a poor substitute for a measurement. Go led the first run. Helidon led the next two. The p99 numbers moved around. The client and server shared one host. The test was short. This is useful signal, not a trophy.

If you want publishable benchmark numbers, extend the harness. Pin CPU. Isolate the load generator. Run longer. Repeat more times. Capture RSS. Capture startup time. Capture CPU. Try containers. Try logging on and off. Try a real JSON library. Try a database call. Try Spring Boot. Try native image. Change one variable at a time.

The moment you do that, the question gets less dramatic and more useful.

## What I Would Change Next

The first thing I would add is a startup and footprint pass. Throughput is only one part of the microservice story. If the service is long-lived, steady-state throughput and tail latency probably matter most. If it is scaled aggressively, deployed often, or used in bursty environments, startup time and memory footprint start to matter a lot more.

The second thing I would add is a logging pass. Keep the same workload, run with `LOG_REQUESTS=false`, then run again with `LOG_REQUESTS=true`. In many real services, the logging and telemetry path is closer to the hot path than people want to admit. If a service spends more time formatting log lines than doing useful work, the language runtime is not the main character.

The third thing I would add is a real dependency. HTTP string manipulation is a clean baseline, but it is not a real application. Add JSON serialization. Add a database call. Add a queue. Add TLS. Add a little bit of validation. Once the service does real work, the runtime can become less important than the libraries, drivers, connection pools, network hops, and back pressure behavior around it.

Finally, I would try the Java side with more than one shape. Helidon SE is intentionally compact. Spring Boot would answer the "what do most Java teams actually use?" question. A GraalVM Native Image build would answer a different startup and footprint question. Those are not replacements for this harness; they are good follow-up experiments.

## What The Results Mean

For this small service shape, Java is absolutely in the same conversation as Go.

That is not the same as saying Java is faster than Go. It is also not the same as saying Go's advantages disappeared. Go still has a very strong operational story for small services: simple builds, straightforward deployment, compact binaries, and a runtime that fits naturally with network servers.

Modern Java has a strong story too. The JVM is mature. The ecosystem is broad. Observability and profiling tools are excellent. Helidon gives us a compact Java server shape. Virtual threads improve the way Java developers can structure many concurrent server applications, especially when blocking I/O is involved.

The practical answer is this:

Use Go when its simplicity, deployment model, team experience, and ecosystem fit the service.

Use Java when the JVM ecosystem, libraries, observability, existing skills, framework options, and operational model fit the service.

Measure when performance matters. Measure the thing you are actually building.

## The Bit I Still Believe

The original article did not settle the question forever. It was never going to. The useful lesson was that performance is not only a property of a language.

It is also a property of:

- hardware shape
- runtime version
- framework choices
- warmup
- logging
- serialization
- container limits
- GC behavior
- load-driver design
- measurement duration
- noisy neighbors
- the parts of the service that are not in your benchmark

That was true in 2020, and it is still true in 2026.

So, can Java microservices be as fast as Go?

For this kind of small HTTP service, on this machine, with these versions, yes, they can be close enough that the more important question is not "which language won?" It is "which runtime shape do you want to live with in production?"

That is a better question. It gives you something to measure, something to argue about productively, and something to improve.

## References

- Original article: https://medium.com/helidon/can-java-microservices-be-as-fast-as-go-5ceb9a45d673
- Go downloads: https://go.dev/dl/
- Go release history: https://go.dev/doc/devel/release
- Go 1.18 release notes, including generics: https://go.dev/doc/go1.18
- Oracle Java downloads: https://www.oracle.com/java/technologies/downloads/
- Oracle Java SE support roadmap: https://www.oracle.com/java/technologies/java-se-support-roadmap.html
- JEP 444, Virtual Threads: https://openjdk.org/jeps/444
- Oracle virtual threads documentation: https://docs.oracle.com/en/java/javase/21/core/virtual-threads.html
- Helidon documentation: https://helidon.io/docs/
- Helidon SE artifact: https://central.sonatype.com/artifact/io.helidon.applications/helidon-se
