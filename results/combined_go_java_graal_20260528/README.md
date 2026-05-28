# Combined Benchmark Results: combined_go_java_graal_20260528

This directory combines the original Go/Oracle JDK run with the later GraalVM run.

- base run: `results/sequential_generated_serious_20260528_1010`
- GraalVM run: `results/sequential_generated_graal_20260528_1218`
- variants: Go stdlib, Oracle JDK JVM, Oracle JDK Leyden AOT, GraalVM JVM, GraalVM Native Image
- payload sizes: 7, 128, 2048, 8192
- concurrency levels: 1, 6, 12, 24, 48, 96, 192

Files:

- `summary-by-cell.csv`
- `peak-throughput-by-payload.csv`
- `throughput-pivot-by-cell.csv`
- `configurations.csv`
