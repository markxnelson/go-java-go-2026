# Article Crew Brief: Go Java Go 2026

Write one updated article, not a series, based on the 2020 Medium article "Can Java microservices be as fast as Go?".

Audience and voice:

- Human readers first.
- Use the RedStack / Mark Nelson voice: conversational, technically careful, practical, curious, and a little opinionated without becoming tribal.
- Do not write an SEO/LLM-style answer card.
- Do not use Markdown tables.

Article purpose:

- Revisit the original question with the latest available language/runtime baselines.
- Explain what has changed since 2020.
- Present a companion code harness readers can run.
- Avoid claiming a universal winner unless real measured results in the same environment support it.
- Make the stronger point: language matters, but runtime, framework, hardware shape, warmup, logging, packaging, and measurement design often matter more.

Current source-backed baselines:

- Go 1.26.3.
- Oracle JDK 26.0.1, with JDK 25.0.3 as the current LTS line.
- Helidon SE 4.4.1.

Companion code location:

- `/home/mark/redstack/go-java-go-2026`

Companion code structure:

- `go-service/`: Go standard library `net/http` service.
- `helidon-service/`: Java Helidon SE WebServer service.
- `bench/`: small Go load driver.
- `scripts/`: local run helpers.

Service contract:

- `GET /health`
- `GET /ready`
- `GET /api/strings/{value}`

Workload:

- Short string manipulation.
- Uppercase, lowercase, reverse, and stable CRC32 hash.
- Optional request logging controlled by `LOG_REQUESTS=true`.
- Same endpoint shape and same output shape for Go and Java.

Important validation summary:

- Go service compiles with Go 1.26.3.
- Benchmark driver compiles with Go 1.26.3.
- Helidon service clean-builds with JDK 26.0.1 and Helidon 4.4.1.
- Smoke tests returned matching output for both services.
- Tiny load-driver checks returned zero failures for both services.
- Do not present the tiny smoke-load checks as meaningful benchmark results.

Article outline preference:

1. Open with the story: six years ago we asked a slightly mischievous question, and it is worth asking again because both ecosystems moved.
2. Recap the original experiment and its main lessons: small service, logging mattered, warmup mattered, hardware shape mattered, Kubernetes changed the picture, no universal winner.
3. Explain what changed in Java and Go since then.
4. Introduce the new companion harness and why it is deliberately modest.
5. Walk through the Go service, the Helidon service, and the load driver at a high level.
6. Explain how to run it locally with Go 1.26.3 and JDK 26.0.1.
7. Discuss how to treat results responsibly: warmups, repeatability, CPU pinning/noisy neighbors, GC/logging settings, container size, startup, RSS, p50/p95/p99, and production realism.
8. End with a nuanced answer: Java microservices can absolutely be in the same conversation as Go; the better question is which runtime and packaging shape fits the service you are building.

Specific things to avoid:

- Do not imply this small harness proves all Java is faster than Go or all Go is faster than Java.
- Do not bury the reader in raw benchmark methodology before they know why the article matters.
- Do not include internal claim ledger language or verification-date clutter in the article body.
- Do not say the original article used "six years ago" without dates; the original was published on 2020-11-05 and this update is being prepared on 2026-05-27.

