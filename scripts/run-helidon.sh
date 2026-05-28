#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${PORT:=8082}"
export PORT

cd "$ROOT/helidon-service"
mvn -B -DskipTests package
exec java -jar target/go-java-go-helidon.jar
