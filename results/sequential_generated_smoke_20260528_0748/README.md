# Benchmark Results: sequential_generated_smoke_20260528_0748

- measurements: 8 rows
- summarized cells: 8 rows
- services: go, helidon
- runtime variants: go-stdlib, oracle-jdk-jvm
- endpoint modes: generated
- payload sizes: 7, 2048
- concurrency levels: 1, 12

## Files

- `measurements.csv`: every repeat from the benchmark matrix.
- `configurations.csv`: runtime configuration and skip/ran status for each variant.
- `summary-by-cell.csv`: repeat-level rollups by runtime, payload, and concurrency.
- `peak-throughput-by-payload.csv`: best median throughput cell for each runtime and payload.
- `throughput-pivot-by-cell.csv`: median throughput pivoted for charting runtime comparisons.
