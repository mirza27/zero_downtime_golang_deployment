#!/usr/bin/env bash
set -euo pipefail

# curl http://208.87.132.201:8080/ || {
#   echo "health check failed" >&2
#   exit 1
# }

# for rollback test
curl http://208.87.132.201:8080/failed || {
  echo "health check failed" >&2
  exit 1
}