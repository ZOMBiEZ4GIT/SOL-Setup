#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../docker"

echo ">> pull images"
docker compose pull

echo ">> up -d"
docker compose up -d

echo ">> restart cloudflared to reload ingress"
docker compose restart cloudflared

echo ">> tail cloudflared routes"
docker compose logs -n 120 cloudflared
