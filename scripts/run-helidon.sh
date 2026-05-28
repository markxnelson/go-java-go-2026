#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${PORT:=8082}"
: "${JAVA_HOME:=/home/mark/jdk-26.0.1}"
: "${JAVA_PROCESSORS:=$(nproc)}"
: "${JAVA_OPTS:=-XX:ActiveProcessorCount=${JAVA_PROCESSORS} -XX:MaxRAMPercentage=75}"
: "${LOG_REQUESTS:=false}"
: "${WORK_FACTOR:=1}"
export PORT
export LOG_REQUESTS
export WORK_FACTOR

cd "$ROOT/helidon-service"
mvn -B -DskipTests package
read -r -a JAVA_OPTS_ARRAY <<< "$JAVA_OPTS"
exec "$JAVA_HOME/bin/java" "${JAVA_OPTS_ARRAY[@]}" -jar target/go-java-go-helidon.jar
