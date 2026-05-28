# 2026 Version Baseline

Prepared on 2026-05-27.

Use these release baselines for the updated article and code:

- Go: 1.26.3, the latest stable Go release identified from the official Go downloads page.
- Java: Oracle JDK 26.0.1, the latest Oracle JDK release identified from the official Oracle Java downloads page.
- Java LTS note: JDK 25 is the current LTS line, so the article should distinguish "latest feature release" from "latest LTS". Oracle's download page lists Java SE Development Kit 25.0.3 downloads for that LTS line.
- Helidon: 4.4.1, the latest Helidon SE artifact identified from Maven metadata.

Local machine snapshot before installing later toolchains:

- `go version`: go1.25.7 linux/amd64
- `java -version`: Oracle JDK 25.0.2 LTS
- `mvn -version`: Apache Maven 3.9.12 using JDK 25.0.2

Article guidance:

- Do not claim absolute language superiority.
- Treat this as an updated experiment and a reproducible harness, not a universal benchmark.
- Explain that Go and Java have both moved since 2020: Go has generics, continued runtime/tooling work, and a mature module workflow; Java has virtual threads, modern GCs, mature containers, faster startup work, and compact frameworks such as Helidon.
- The point is not "Java wins" or "Go wins"; the point is that the runtime, hardware shape, container packaging, logging, warmup, and measurement method often matter more than the language slogan.
