# Benchmark Results: sequential_generated_graal_20260528_1218

- measurements: 112 rows
- summarized cells: 56 rows
- services: helidon
- runtime variants: graalvm-jvm, graalvm-native
- endpoint modes: generated
- payload sizes: 7, 128, 2048, 8192
- concurrency levels: 1, 6, 12, 24, 48, 96, 192

## Files

- `measurements.csv`: every repeat from the benchmark matrix.
- `configurations.csv`: runtime configuration and skip/ran status for each variant.
- `summary-by-cell.csv`: repeat-level rollups by runtime, payload, and concurrency.
- `peak-throughput-by-payload.csv`: best median throughput cell for each runtime and payload.
- `throughput-pivot-by-cell.csv`: median throughput pivoted for charting runtime comparisons.
