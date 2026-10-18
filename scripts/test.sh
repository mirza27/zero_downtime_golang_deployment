#!/usr/bin/env bash

URL="${1:-http://localhost:8080/}"
INTERVAL=0.250

while true; do
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S.%3N')

    echo "========================================"
    printf '[%s] Request: %s\n' "$TIMESTAMP" "$URL"

    curl -sS \
        --max-time 10 \
        -w '\nHTTP Status: %{http_code}\nResponse Time: %{time_total}s\n' \
        "$URL"

    echo
    sleep "$INTERVAL"
done
