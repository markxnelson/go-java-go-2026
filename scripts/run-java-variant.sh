#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${VARIANT:=oracle-jdk-jvm}"
: "${JAVA_HOME:=/home/mark/jdk-26.0.1}"
: "${PORT:=8082}"
: "${JAVA_PROCESSORS:=$(nproc)}"
: "${JAVA_OPTS:=-XX:ActiveProcessorCount=${JAVA_PROCESSORS} -XX:MaxRAMPercentage=75}"
: "${LOG_REQUESTS:=false}"
: "${WORK_FACTOR:=1}"
: "${AOT_CACHE:=$ROOT/helidon-service/target/aot/go-java-go-helidon.aot}"

export PORT
export LOG_REQUESTS
export WORK_FACTOR

cd "$ROOT/helidon-service"

read -r -a JAVA_OPTS_ARRAY <<< "$JAVA_OPTS"

case "$VARIANT" in
  oracle-jdk-jvm)
    exec "$JAVA_HOME/bin/java" "${JAVA_OPTS_ARRAY[@]}" -jar target/go-java-go-helidon.jar
    ;;
  oracle-jdk-leyden-aot)
    if [[ ! -f "$AOT_CACHE" ]]; then
      echo "Leyden AOT cache not found: $AOT_CACHE" >&2
      echo "Run scripts/prepare-leyden-aot.sh first." >&2
      exit 2
    fi
    exec "$JAVA_HOME/bin/java" "${JAVA_OPTS_ARRAY[@]}" -XX:AOTCache="$AOT_CACHE" -jar target/go-java-go-helidon.jar
    ;;
  *)
    echo "Unknown VARIANT: $VARIANT" >&2
    exit 2
    ;;
esac
