#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${PORT:=8081}"
: "${GOMAXPROCS:=$(nproc)}"
: "${GOMEMLIMIT:=off}"
: "${LOG_REQUESTS:=false}"
: "${WORK_FACTOR:=1}"
: "${GOCACHE:=/tmp/go-java-go-2026-go-cache}"
: "${GO_BIN:=$ROOT/go-service/target/go-java-go-server}"
export PORT
export GOMAXPROCS
export GOMEMLIMIT
export LOG_REQUESTS
export WORK_FACTOR
export GOCACHE

cd "$ROOT/go-service"
mkdir -p "$(dirname "$GO_BIN")"
go build -o "$GO_BIN" ./cmd/server
exec "$GO_BIN"
