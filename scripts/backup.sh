#!/usr/bin/env bash
set -euo pipefail
TS=$(date +%F_%H%M)
ROOT="$(dirname "$0")/.."
cd "$ROOT"
tar czf "homelab_backup_$TS.tgz" \
  docker/n8n docker/sonarr docker/radarr docker/qbittorrent docker/plex \
  docker/prowlarr docker/bazarr docker/overseerr docker/tautulli \
  docker/glances docker/uptime-kuma docker/dozzle \
  docker/adguard docker/cloudflared/config.yml docs || true
echo "Backup created: $(pwd)/homelab_backup_$TS.tgz"
