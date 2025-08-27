#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../docker"

echo ">> docker compose lint/merge"
docker compose config >/dev/null

echo ">> quick local port checks"
ports=(32400 8989 7878 5678 8080 9000 7575 9696 6767 5055 8181 61208 3001 9999 3000)
for p in "${ports[@]}"; do
  (curl -fsS "http://127.0.0.1:$p" -m 1 >/dev/null && echo "port $p OK") || echo "port $p n/a"
done
