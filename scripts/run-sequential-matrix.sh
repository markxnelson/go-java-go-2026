#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="${RESULTS_DIR:-$ROOT/results/sequential_$(date +%Y%m%d_%H%M%S)}"
mkdir -p "$RESULTS_DIR"
RUN_ID="$(basename "$RESULTS_DIR")"

: "${GO_PORT:=8081}"
: "${JAVA_PORT:=8082}"
: "${CONCURRENCY_LEVELS:=1 6 12 24 48 96}"
: "${PAYLOAD_SIZES:=7 128 2048}"
: "${REPEATS:=2}"
: "${DURATION:=8s}"
: "${WARMUP_DURATION:=10s}"
: "${SERVICE_WARMUP_DURATION:=10s}"
: "${WORK_FACTOR:=1}"
: "${ENDPOINT_MODE:=generated}"
: "${LOG_REQUESTS:=false}"
: "${GOMAXPROCS:=$(nproc)}"
: "${GOMEMLIMIT:=off}"
: "${JAVA_PROCESSORS:=$(nproc)}"
: "${JAVA_OPTS:=-XX:ActiveProcessorCount=${JAVA_PROCESSORS} -XX:MaxRAMPercentage=75}"
: "${LEYDEN_JAVA_OPTS:=-XX:+UnlockDiagnosticVMOptions -XX:-AOTRecordTraining -XX:-AOTReplayTraining}"
: "${JAVA_VARIANTS:=oracle-jdk-jvm oracle-jdk-leyden-aot}"
: "${RUN_GO:=true}"

SERVICE_PID=""

cleanup() {
  if [[ -n "$SERVICE_PID" ]] && kill -0 "$SERVICE_PID" 2>/dev/null; then
    kill -TERM "$SERVICE_PID" 2>/dev/null || true
    wait "$SERVICE_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

wait_for_health() {
  local port="$1"
  local target="$RESULTS_DIR/$2-health.json"
  for _ in $(seq 1 120); do
    if curl -fsS "http://localhost:${port}/health" > "$target" 2>/dev/null; then
      return 0
    fi
    sleep 0.25
  done
  echo "Timed out waiting for port $port" >&2
  return 1
}

wait_for_shutdown() {
  local port="$1"
  for _ in $(seq 1 120); do
    if ! curl -fsS "http://localhost:${port}/health" > /dev/null 2>&1; then
      return 0
    fi
    sleep 0.25
  done
  echo "Timed out waiting for port $port to stop accepting health checks" >&2
  return 1
}

payload() {
  local size="$1"
  if [[ "$size" == "7" ]]; then
    printf "Helidon"
    return
  fi
  printf "%*s" "$size" "" | tr " " "x"
}

warmup_url() {
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

duration_seconds() {
  local duration="$1"
  case "$duration" in
    *ms)
      echo 1
      ;;
    *s)
      echo "${duration%s}"
      ;;
    *m)
      echo "$(( ${duration%m} * 60 ))"
      ;;
    *h)
      echo "$(( ${duration%h} * 3600 ))"
      ;;
    *)
      echo "$duration"
      ;;
  esac
}

warm_service_after_start() {
  local port="$1"
  local service="$2"
  local duration="$SERVICE_WARMUP_DURATION"
  local seconds
  local start
  local url

  if [[ "$duration" == "0" || "$duration" == "0s" ]]; then
    return 0
  fi

  echo "Warming $service service for $duration before benchmark measurements"
  seconds="$(duration_seconds "$duration")"
  start="$SECONDS"
  while (( SECONDS - start < seconds )); do
    for payload_size in $PAYLOAD_SIZES; do
      url="$(warmup_url "$port" "$payload_size")"
      curl -fsS --max-time 5 "$url" > /dev/null || true
      if (( SECONDS - start >= seconds )); then
        break
      fi
    done
  done
}

run_service_matrix() {
  local service="$1"
  local runtime_variant="$2"
  local port="$3"
  local service_results="$RESULTS_DIR/$runtime_variant"
  mkdir -p "$service_results"
  RESULTS_DIR="$service_results" \
    GO_PORT="$GO_PORT" \
    JAVA_PORT="$JAVA_PORT" \
    CONCURRENCY_LEVELS="$CONCURRENCY_LEVELS" \
    PAYLOAD_SIZES="$PAYLOAD_SIZES" \
    REPEATS="$REPEATS" \
    DURATION="$DURATION" \
    WARMUP_DURATION="$WARMUP_DURATION" \
    SERVICES="$service" \
    RUN_ID="$RUN_ID" \
    RUNTIME_VARIANT="$runtime_variant" \
    WORK_FACTOR="$WORK_FACTOR" \
    ENDPOINT_MODE="$ENDPOINT_MODE" \
    scripts/run-benchmark-matrix.sh
  cp "$service_results/summary.csv" "$RESULTS_DIR/${runtime_variant}-summary.csv"
  cp "$service_results/environment.txt" "$RESULTS_DIR/${runtime_variant}-environment.txt"
}

append_measurements() {
  local source="$1"
  if [[ ! -f "$RESULTS_DIR/measurements.csv" ]]; then
    cp "$source" "$RESULTS_DIR/measurements.csv"
  else
    tail -n +2 "$source" >> "$RESULTS_DIR/measurements.csv"
  fi
}

record_configuration() {
  local runtime_variant="$1"
  local service="$2"
  local status="$3"
  local notes="$4"
  local effective_leyden_java_opts=""
  if [[ "$runtime_variant" == "oracle-jdk-leyden-aot" ]]; then
    effective_leyden_java_opts="$LEYDEN_JAVA_OPTS"
  fi
  printf "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n" \
    "$(basename "$RESULTS_DIR")" \
    "$runtime_variant" \
    "$service" \
    "$status" \
    "$WORK_FACTOR" \
    "$ENDPOINT_MODE" \
    "$LOG_REQUESTS" \
    "$GOMAXPROCS" \
    "$GOMEMLIMIT" \
    "$JAVA_PROCESSORS" \
    "\"$JAVA_OPTS\"" \
    "\"$effective_leyden_java_opts\"" \
    "$SERVICE_WARMUP_DURATION" \
    "\"$notes\"" >> "$RESULTS_DIR/configurations.csv"
}

{
  date -Iseconds
  uname -a
  lscpu
  free -h
  go version || true
  /home/mark/jdk-26.0.1/bin/java -version || true
  echo "GO_PORT=$GO_PORT"
  echo "JAVA_PORT=$JAVA_PORT"
  echo "CONCURRENCY_LEVELS=$CONCURRENCY_LEVELS"
  echo "PAYLOAD_SIZES=$PAYLOAD_SIZES"
  echo "REPEATS=$REPEATS"
  echo "DURATION=$DURATION"
  echo "WARMUP_DURATION=$WARMUP_DURATION"
  echo "SERVICE_WARMUP_DURATION=$SERVICE_WARMUP_DURATION"
  echo "WORK_FACTOR=$WORK_FACTOR"
  echo "ENDPOINT_MODE=$ENDPOINT_MODE"
  echo "LOG_REQUESTS=$LOG_REQUESTS"
  echo "GOMAXPROCS=$GOMAXPROCS"
  echo "GOMEMLIMIT=$GOMEMLIMIT"
  echo "JAVA_PROCESSORS=$JAVA_PROCESSORS"
  echo "JAVA_OPTS=$JAVA_OPTS"
  echo "LEYDEN_JAVA_OPTS=$LEYDEN_JAVA_OPTS"
  echo "JAVA_VARIANTS=$JAVA_VARIANTS"
  echo "RUN_GO=$RUN_GO"
} > "$RESULTS_DIR/environment.txt" 2>&1

echo "runId,runtimeVariant,service,status,workFactor,endpointMode,logRequests,gomaxprocs,goMemLimit,javaProcessors,javaOpts,leydenJavaOpts,serviceWarmupDuration,notes" > "$RESULTS_DIR/configurations.csv"

if [[ "$RUN_GO" == "true" ]]; then
  wait_for_shutdown "$GO_PORT"
  echo "Starting Go service alone"
  (
    cd "$ROOT"
    exec env \
      PORT="$GO_PORT" \
      LOG_REQUESTS="$LOG_REQUESTS" \
      WORK_FACTOR="$WORK_FACTOR" \
      GOMAXPROCS="$GOMAXPROCS" \
      GOMEMLIMIT="$GOMEMLIMIT" \
      scripts/run-go.sh
  ) > "$RESULTS_DIR/go-service.log" 2>&1 &
  SERVICE_PID="$!"
  if ! wait_for_health "$GO_PORT" "go"; then
    record_configuration "go-stdlib" "go" "skipped" "Health check failed; see go-service.log"
    cleanup
    wait_for_shutdown "$GO_PORT"
    SERVICE_PID=""
  else
    warm_service_after_start "$GO_PORT" "go-stdlib"
    record_configuration "go-stdlib" "go" "ran" "Go net/http, GOMAXPROCS set explicitly"
    run_service_matrix "go" "go-stdlib" "$GO_PORT"
    append_measurements "$RESULTS_DIR/go-stdlib/summary.csv"
    cleanup
    wait_for_shutdown "$GO_PORT"
    SERVICE_PID=""
  fi
fi

for variant in $JAVA_VARIANTS; do
  case "$variant" in
    oracle-jdk-leyden-aot)
      echo "Preparing Leyden AOT cache"
      if ! JAVA_HOME="/home/mark/jdk-26.0.1" JAVA_PROCESSORS="$JAVA_PROCESSORS" JAVA_OPTS="$JAVA_OPTS" WORK_FACTOR="$WORK_FACTOR" LOG_REQUESTS="$LOG_REQUESTS" scripts/prepare-leyden-aot.sh > "$RESULTS_DIR/leyden-prepare.out" 2> "$RESULTS_DIR/leyden-prepare.err"; then
        record_configuration "$variant" "helidon" "skipped" "Leyden AOT cache preparation failed; see leyden-prepare.err"
        continue
      fi
      ;;
  esac

  wait_for_shutdown "$JAVA_PORT"
  echo "Starting Helidon service alone: $variant"
  (
    cd "$ROOT"
    exec env \
      VARIANT="$variant" \
      PORT="$JAVA_PORT" \
      LOG_REQUESTS="$LOG_REQUESTS" \
      WORK_FACTOR="$WORK_FACTOR" \
      JAVA_PROCESSORS="$JAVA_PROCESSORS" \
      JAVA_OPTS="$JAVA_OPTS" \
      LEYDEN_JAVA_OPTS="$LEYDEN_JAVA_OPTS" \
      scripts/run-java-variant.sh
  ) > "$RESULTS_DIR/${variant}-service.log" 2>&1 &
  SERVICE_PID="$!"
  if ! wait_for_health "$JAVA_PORT" "$variant"; then
    record_configuration "$variant" "helidon" "skipped" "Health check failed; see ${variant}-service.log"
    cleanup
    wait_for_shutdown "$JAVA_PORT"
    SERVICE_PID=""
    continue
  fi
  warm_service_after_start "$JAVA_PORT" "$variant"
  record_configuration "$variant" "helidon" "ran" "Helidon SE; health output records virtual-thread request handling"
  run_service_matrix "helidon" "$variant" "$JAVA_PORT"
  append_measurements "$RESULTS_DIR/$variant/summary.csv"
  cleanup
  wait_for_shutdown "$JAVA_PORT"
  SERVICE_PID=""
done

python3 scripts/summarize-results.py "$RESULTS_DIR"

echo "Results saved under $RESULTS_DIR"
