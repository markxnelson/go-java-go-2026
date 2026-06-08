#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="${RESULTS_DIR:-$ROOT/results/matrix_$(date +%Y%m%d_%H%M%S)}"
mkdir -p "$RESULTS_DIR"

: "${GO_PORT:=8081}"
: "${JAVA_PORT:=8082}"
: "${CONCURRENCY_LEVELS:=1 6 12 24 48 96 192}"
: "${PAYLOAD_SIZES:=7 128 2048}"
: "${REPEATS:=2}"
: "${DURATION:=8s}"
: "${WARMUP_DURATION:=10s}"
: "${LOAD_CPUSET:=}"
: "${SERVICES:=go helidon}"
: "${RUN_ID:=$(date +%Y%m%d_%H%M%S)}"
: "${RUNTIME_VARIANT:=unspecified}"
: "${WORK_FACTOR:=1}"
: "${ENDPOINT_MODE:=generated}"
: "${LOAD_GOCACHE:=/tmp/go-java-go-2026-bench-cache}"

LOAD_BIN="$RESULTS_DIR/load"

(
  cd "$ROOT/bench"
  GOCACHE="$LOAD_GOCACHE" go build -o "$LOAD_BIN" ./cmd/load
)

{
  date -Iseconds
  uname -a
  lscpu
  free -h
  go version || true
  java -version || true
  mvn -version || true
  echo "GO_PORT=$GO_PORT"
  echo "JAVA_PORT=$JAVA_PORT"
  echo "CONCURRENCY_LEVELS=$CONCURRENCY_LEVELS"
  echo "PAYLOAD_SIZES=$PAYLOAD_SIZES"
  echo "REPEATS=$REPEATS"
  echo "DURATION=$DURATION"
  echo "WARMUP_DURATION=$WARMUP_DURATION"
  echo "LOAD_CPUSET=$LOAD_CPUSET"
  echo "SERVICES=$SERVICES"
  echo "RUN_ID=$RUN_ID"
  echo "RUNTIME_VARIANT=$RUNTIME_VARIANT"
  echo "WORK_FACTOR=$WORK_FACTOR"
  echo "ENDPOINT_MODE=$ENDPOINT_MODE"
  echo "LOAD_GOCACHE=$LOAD_GOCACHE"
} > "$RESULTS_DIR/environment.txt" 2>&1

echo "runId,runtimeVariant,service,workFactor,endpointMode,payloadSize,concurrency,repeat,requests,failures,elapsed,requestsPerSecond,p50,p95,p99,p999,min,max,p50Nanos,p95Nanos,p99Nanos,p999Nanos,minNanos,maxNanos" > "$RESULTS_DIR/summary.csv"

payload() {
  local size="$1"
  if [[ "$size" == "7" ]]; then
    printf "Helidon"
    return
  fi
  printf "%*s" "$size" "" | tr " " "x"
}

field() {
  local key="$1"
  local file="$2"
  awk -F= -v key="$key" '$1 == key {print $2; exit}' "$file"
}

benchmark_url() {
  local port="$1"
  local payload_size="$2"
  local value

  case "$ENDPOINT_MODE" in
    generated)
      printf "http://localhost:%s/api/generated/%s" "$port" "$payload_size"
      ;;
    path)
      value="$(payload "$payload_size")"
      printf "http://localhost:%s/api/strings/%s" "$port" "$value"
      ;;
    *)
      echo "Unknown ENDPOINT_MODE: $ENDPOINT_MODE" >&2
      return 2
      ;;
  esac
}

run_one() {
  local service="$1"
  local port="$2"
  local payload_size="$3"
  local concurrency="$4"
  local repeat="$5"
  local url
  local output

  url="$(benchmark_url "$port" "$payload_size")"
  output="$RESULTS_DIR/${service}_size${payload_size}_c${concurrency}_r${repeat}.txt"

  echo "service=$service endpointMode=$ENDPOINT_MODE payloadSize=$payload_size concurrency=$concurrency repeat=$repeat"
  if [[ -n "$LOAD_CPUSET" ]]; then
    taskset -c "$LOAD_CPUSET" "$LOAD_BIN" \
      -url "$url" \
      -concurrency "$concurrency" \
      -duration "$DURATION" \
      -warmup-duration "$WARMUP_DURATION" > "$output"
  else
    "$LOAD_BIN" \
      -url "$url" \
      -concurrency "$concurrency" \
      -duration "$DURATION" \
      -warmup-duration "$WARMUP_DURATION" > "$output"
  fi

  printf "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n" \
    "$RUN_ID" \
    "$RUNTIME_VARIANT" \
    "$service" \
    "$WORK_FACTOR" \
    "$ENDPOINT_MODE" \
    "$payload_size" \
    "$concurrency" \
    "$repeat" \
    "$(field requests "$output")" \
    "$(field failures "$output")" \
    "$(field elapsed "$output")" \
    "$(field requestsPerSecond "$output")" \
    "$(field p50 "$output")" \
    "$(field p95 "$output")" \
    "$(field p99 "$output")" \
    "$(field p999 "$output")" \
    "$(field min "$output")" \
    "$(field max "$output")" \
    "$(field p50Nanos "$output")" \
    "$(field p95Nanos "$output")" \
    "$(field p99Nanos "$output")" \
    "$(field p999Nanos "$output")" \
    "$(field minNanos "$output")" \
    "$(field maxNanos "$output")" >> "$RESULTS_DIR/summary.csv"
}

for service in $SERVICES; do
  port="$GO_PORT"
  if [[ "$service" == "helidon" ]]; then
    port="$JAVA_PORT"
  fi
  for payload_size in $PAYLOAD_SIZES; do
    for concurrency in $CONCURRENCY_LEVELS; do
      for repeat in $(seq 1 "$REPEATS"); do
        run_one "$service" "$port" "$payload_size" "$concurrency" "$repeat"
      done
    done
  done
done

echo "Results saved under $RESULTS_DIR"
