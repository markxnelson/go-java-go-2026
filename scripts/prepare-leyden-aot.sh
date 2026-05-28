#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${JAVA_HOME:=/home/mark/jdk-26.0.1}"
: "${JAVA_PROCESSORS:=$(nproc)}"
: "${JAVA_OPTS:=-XX:ActiveProcessorCount=${JAVA_PROCESSORS} -XX:MaxRAMPercentage=75}"
: "${PORT:=28082}"
: "${WORK_FACTOR:=1}"
: "${LOG_REQUESTS:=false}"
: "${AOT_DIR:=$ROOT/helidon-service/target/aot}"
: "${AOT_NAME:=go-java-go-helidon}"

mkdir -p "$AOT_DIR"
AOT_CONFIG="$AOT_DIR/${AOT_NAME}.aotconf"
AOT_CACHE="$AOT_DIR/${AOT_NAME}.aot"

cd "$ROOT/helidon-service"
mvn -B -DskipTests package

read -r -a JAVA_OPTS_ARRAY <<< "$JAVA_OPTS"

rm -f "$AOT_CONFIG" "$AOT_CACHE"

PORT="$PORT" LOG_REQUESTS="$LOG_REQUESTS" WORK_FACTOR="$WORK_FACTOR" \
  "$JAVA_HOME/bin/java" \
    "${JAVA_OPTS_ARRAY[@]}" \
    -XX:AOTMode=record \
    -XX:AOTConfiguration="$AOT_CONFIG" \
    -jar target/go-java-go-helidon.jar > "$AOT_DIR/record.log" 2>&1 &
server_pid="$!"

cleanup() {
  if kill -0 "$server_pid" 2>/dev/null; then
    kill -TERM "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
  fi
}
trap cleanup EXIT

for _ in $(seq 1 120); do
  if curl -fsS "http://localhost:${PORT}/health" > "$AOT_DIR/record-health.json" 2>/dev/null; then
    break
  fi
  sleep 0.25
done

curl -fsS "http://localhost:${PORT}/api/generated/7" > "$AOT_DIR/record-string-small.json"
curl -fsS "http://localhost:${PORT}/api/generated/128" > "$AOT_DIR/record-string-128.json"
curl -fsS "http://localhost:${PORT}/api/generated/2048" > "$AOT_DIR/record-string-2048.json"

cleanup
trap - EXIT

"$JAVA_HOME/bin/java" \
  "${JAVA_OPTS_ARRAY[@]}" \
  -XX:AOTMode=create \
  -XX:AOTConfiguration="$AOT_CONFIG" \
  -XX:AOTCacheOutput="$AOT_CACHE" \
  -jar target/go-java-go-helidon.jar > "$AOT_DIR/create.log" 2>&1

echo "$AOT_CACHE"
