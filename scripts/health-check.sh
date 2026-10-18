#!/usr/bin/env bash
set -euo pipefail

curl http://208.87.132.201:8080/ || {
  echo "health check failed" >&2
  exit 1
}

# for rollback test
# curl --show-error \
#   --connect-timeout 2 \
#   --max-time 5 \
#   http://208.87.132.200:8080/ || {
#   echo "health check failed" >&2
#   exit 1
# }