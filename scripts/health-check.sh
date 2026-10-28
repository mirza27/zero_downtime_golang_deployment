#!/usr/bin/env bash
set -euo pipefail

TARGET_HOST="${TARGET_HOST:-localhost}"
TARGET_PORT="${TARGET_PORT:-8080}"

curl -f "http://${TARGET_HOST}:${TARGET_PORT}/" || {
  echo "health check failed" >&2
  exit 1
}

# for rollback test
# curl -f --connect-timeout 2 --max-time 5 "http://${TARGET_HOST}:9999/" || {
#   echo "health check failed" >&2
#   exit 1
# }