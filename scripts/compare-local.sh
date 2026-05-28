#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT/results/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RESULTS_DIR"

: "${CONCURRENCY:=100}"
: "${REQUESTS:=100000}"
: "${WARMUP:=1000}"
: "${GO_PORT:=8081}"
: "${JAVA_PORT:=8082}"

{
  date -Iseconds
  go version || true
  java -version || true
  mvn -version || true
} > "$RESULTS_DIR/environment.txt" 2>&1

echo "Benchmarking Go service on port $GO_PORT"
(
  cd "$ROOT/bench"
  go run ./cmd/load \
    -url "http://localhost:${GO_PORT}/api/strings/Helidon" \
    -concurrency "$CONCURRENCY" \
    -requests "$REQUESTS" \
    -warmup "$WARMUP"
) | tee "$RESULTS_DIR/go.txt"

echo "Benchmarking Helidon service on port $JAVA_PORT"
(
  cd "$ROOT/bench"
  go run ./cmd/load \
    -url "http://localhost:${JAVA_PORT}/api/strings/Helidon" \
    -concurrency "$CONCURRENCY" \
    -requests "$REQUESTS" \
    -warmup "$WARMUP"
) | tee "$RESULTS_DIR/helidon.txt"

echo "Results saved under $RESULTS_DIR"

