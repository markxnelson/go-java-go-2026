#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${PORT:=8081}"
export PORT

cd "$ROOT/go-service"
exec go run ./cmd/server
