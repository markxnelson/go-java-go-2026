# Benchmark Results: sequential_generated_leyden_feedback_full_20260608_070043

- measurements: 168 rows
- summarized cells: 84 rows
- services: go, helidon
- runtime variants: go-stdlib, oracle-jdk-jvm, oracle-jdk-leyden-aot
- endpoint modes: generated
- payload sizes: 7, 128, 2048, 8192
- concurrency levels: 1, 6, 12, 24, 48, 96, 192

## Files

- `measurements.csv`: every repeat from the benchmark matrix.
- `configurations.csv`: runtime configuration and skip/ran status for each variant.
- `summary-by-cell.csv`: repeat-level rollups by runtime, payload, and concurrency.
- `peak-throughput-by-payload.csv`: best median throughput cell for each runtime and payload.
- `throughput-pivot-by-cell.csv`: median throughput pivoted for charting runtime comparisons.
