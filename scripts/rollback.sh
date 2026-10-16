#!/usr/bin/env bash
set -euo pipefail

CONTAINER=technical-test-simple-server
STATE=./state

mkdir -p "$STATE"

CURRENT="$(cat "$STATE/current.txt")"
PREVIOUS="$(cat "$STATE/previous.txt")"

[[ "$PREVIOUS" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || exit 2
[[ -x "./releases/$PREVIOUS/server" ]] || exit 1

printf '%s\n' "$CURRENT" > "$STATE/previous.txt"

docker exec "$CONTAINER" sh -ec "
    ln -s '/releases/$PREVIOUS/server' /app/server.next
    mv -Tf /app/server.next /app/server
" 
printf '%s\n' "$PREVIOUS" > "$STATE/current.txt"

docker kill --signal=USR1 "$CONTAINER" || echo "failed restart" >&2
