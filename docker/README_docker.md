# Docker Setup Guide

## Host Directory Setup

Before starting the containers, create the required host directories:

```bash
sudo mkdir -p /srv/media/{movies,tv} /srv/downloads
sudo chown -R $USER:$USER /srv
```

These directories will be mounted into the containers for media storage and downloads.

## Docker Compose Usage

### Linting and Validation

Before deploying, always validate the compose file:

```bash
cd docker
docker compose config
```

This will parse and validate the YAML without starting services. Note: You may see a warning about the `version` key being obsolete - this is expected as we're using Compose v2 format without the version key.

### Starting Services

Start all services:
```bash
docker compose up -d
```

Start specific services:
```bash
docker compose up -d plex sonarr radarr
```

### Updating Images

Pull latest images:
```bash
docker compose pull
```

Redeploy with new images:
```bash
docker compose up -d
```

### Managing Services

View running containers:
```bash
docker compose ps
```

View logs:
```bash
docker compose logs -f cloudflared
docker compose logs -f --tail=100 gluetun
```

Stop services:
```bash
docker compose stop
docker compose down  # Also removes containers
```

## Environment Variables

1. Copy the environment template:
   ```bash
   cp env.template .env
   ```

2. Edit `.env` and fill in your actual values:
   - ProtonVPN credentials
   - User/Group IDs if different from 1000:1000
   - Timezone if not Australia/Melbourne

## Important Notes

- **No version key**: This compose file uses Compose v2 format and omits the obsolete `version:` key
- **Host networking**: Plex, AdGuard Home, and Cloudflared use host networking for direct port access
- **VPN routing**: qBittorrent runs through the gluetun VPN container for privacy
- **Permissions**: All LinuxServer.io containers run as PUID:PGID specified in .env

## Service Ports

When all services are running, these ports will be available on localhost:

- Plex: 32400
- Sonarr: 8989
- Radarr: 7878
- n8n: 5678
- qBittorrent: 8080 (via gluetun)
- Portainer: 9000, 9443
- Homarr: 7575
- Prowlarr: 9696
- Bazarr: 6767
- Overseerr: 5055
- Tautulli: 8181
- Glances: 61208
- Uptime-Kuma: 3001
- Dozzle: 9999
- AdGuard Home: 3000 (first-run), 53 (DNS)
