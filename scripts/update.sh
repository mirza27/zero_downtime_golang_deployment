#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?Usage: deploy.sh VERSION}"

CONTAINER=technical-test-simple-server
STATE=./state

mkdir -p "$STATE"

[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || exit 2
[[ -x "./releases/$VERSION/server" ]] || {
  echo "built release not found: $VERSION" >&2
  exit 1
}

CURRENT="$(cat "$STATE/current.txt")"
printf '%s\n' "$CURRENT" > "$STATE/previous.txt"

docker exec  "$CONTAINER" sh -ec "
    ln -s '/releases/$VERSION/server' /app/server.next
    mv -Tf /app/server.next /app/server
" 

printf '%s\n' "$VERSION" > "$STATE/current.txt"

docker kill --signal=USR1 "$CONTAINER" || echo "failed restart" >&2