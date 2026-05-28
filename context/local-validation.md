# Local Validation Notes

Validation date: 2026-05-27

Toolchains:

- Active Go after update: `go version go1.26.3 linux/amd64`
- JDK 26 install: `/home/mark/jdk-26.0.1`
- JDK 26 runtime: `java version "26.0.1" 2026-04-21`
- Maven with JDK 26: Apache Maven 3.9.12, Java 26.0.1

Build checks:

- `GOCACHE=/tmp/go-java-go-2026-go-cache go test ./...` passed for `go-service`.
- `GOCACHE=/tmp/go-java-go-2026-bench-cache go test ./...` passed for `bench`.
- `JAVA_HOME=/home/mark/jdk-26.0.1 PATH=/home/mark/jdk-26.0.1/bin:/home/mark/apache-maven-3.9.12/bin:/usr/local/go/bin:/usr/bin:/bin mvn -B -DskipTests clean package` passed for `helidon-service`.

Smoke checks:

- Go service was run with Go 1.26.3 on port 18081.
- Helidon service was run with Helidon 4.4.1 on JDK 26.0.1 on port 18082.
- `GET /health` succeeded for both services.
- `GET /api/strings/Helidon` succeeded for both services.
- Both services returned the same transformed values and hash:
  - uppercase: `HELIDON`
  - lowercase: `helidon`
  - reversed: `nodileH`
  - hash: `2951479431`
- The benchmark harness returned zero failures in a tiny loopback smoke run against both services.

Important article note:

- These tiny smoke checks validate the companion code and harness. They are not benchmark results and should not be presented as performance conclusions.

Local comparison runs:

- Ran after the later toolchains were installed, with Go on port 19081 and Helidon on port 19082.
- Command:
  - `CONCURRENCY=100 REQUESTS=100000 WARMUP=5000 GO_PORT=19081 JAVA_PORT=19082 scripts/compare-local.sh`
- Request logging was disabled for both services.
- Client and servers ran on the same host.
- No CPU pinning, containers, JVM tuning flags, or separate load-generator host were used.
- Result directories:
  - `results/20260527_195405`
  - `results/20260527_195422`
  - `results/20260527_195540`
- Average throughput across those three passes:
  - Go: about 25.8k requests/sec.
  - Helidon: about 24.3k requests/sec.

Article guidance for those comparison runs:

- These are local, short, same-host measurements.
- They are useful evidence that the two services are in the same general neighborhood for this workload.
- They are not a universal benchmark and should not be framed as a general language ranking.
