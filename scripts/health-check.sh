#!/usr/bin/env bash
set -euo pipefail

curl http://localhost:8080/ || {
  echo "health check failed" >&2
  exit 1
}