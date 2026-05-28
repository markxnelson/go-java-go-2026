#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${GRAALVM_HOME:=}"
: "${NATIVE_IMAGE:=native-image}"
: "${NATIVE_IMAGE_NAME:=go-java-go-helidon-native}"

if [[ -n "$GRAALVM_HOME" ]]; then
  NATIVE_IMAGE="$GRAALVM_HOME/bin/native-image"
fi

if [[ ! -x "$(command -v "$NATIVE_IMAGE" 2>/dev/null || true)" && ! -x "$NATIVE_IMAGE" ]]; then
  echo "native-image not found. Install GraalVM Native Image or set GRAALVM_HOME." >&2
  exit 2
fi

cd "$ROOT/helidon-service"
mvn -B -DskipTests package

"$NATIVE_IMAGE" \
  --no-fallback \
  -H:+ReportExceptionStackTraces \
  -jar target/go-java-go-helidon.jar \
  "target/${NATIVE_IMAGE_NAME}"

echo "$ROOT/helidon-service/target/${NATIVE_IMAGE_NAME}"
