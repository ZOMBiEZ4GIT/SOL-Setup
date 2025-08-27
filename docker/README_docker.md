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
   - **Optional**: Shoutrrr URL for Watchtower notifications
   - **Optional**: Grafana admin password

## Security Features

### Security Constraints
All containers (except those requiring elevated privileges) run with enhanced security:
- `security_opt: ["no-new-privileges:true"]` prevents privilege escalation
- **Note**: `gluetun` requires `NET_ADMIN` capability for VPN functionality

### Health Checks
All services include health checks for improved monitoring:
- **Interval**: 30 seconds between checks
- **Timeout**: 10 seconds for response
- **Retries**: 3 attempts before marking unhealthy
- **Start Period**: 60 seconds grace period for startup

### Resource Management
Resource limits and reservations prevent resource exhaustion:

| Service | Memory Limit | CPU Limit | Memory Reservation | CPU Reservation |
|---------|--------------|-----------|-------------------|-----------------|
| Plex | 2GB | 1.0 CPU | 512MB | 0.25 CPU |
| n8n | 1GB | 0.5 CPU | 256MB | 0.1 CPU |
| Sonarr/Radarr | 512MB | 0.5 CPU | 128MB | 0.1 CPU |
| qBittorrent | 1GB | 0.5 CPU | 256MB | 0.1 CPU |
| Others | 256MB | 0.25 CPU | 64MB | 0.05 CPU |

## Logging & Monitoring

### Centralized Logging (Loki)
All services use structured logging with Loki:
- **Loki**: Log aggregation and storage
- **Promtail**: Log collection and forwarding
- **Grafana**: Log visualization and querying

### Metrics Collection (Prometheus)
Comprehensive system and service monitoring:
- **Prometheus**: Metrics collection and storage
- **Node Exporter**: Host system metrics
- **cAdvisor**: Container metrics
- **Grafana**: Metrics visualization and dashboards

### Automated Updates (Watchtower)
Automatic container updates with rollback capability:
- **Update Interval**: 24 hours
- **Cleanup**: Removes old images automatically
- **Notifications**: Configurable via Shoutrrr (Discord, Slack, Email, Telegram)
- **Label-based**: Only updates containers with `com.centurylinklabs.watchtower.enable=true`

## Important Notes

- **No version key**: This compose file uses Compose v2 format and omits the obsolete `version:` key
- **Host networking**: Plex, AdGuard Home, and Cloudflared use host networking for direct port access
- **VPN routing**: qBittorrent runs through the gluetun VPN container for privacy
- **Permissions**: All LinuxServer.io containers run as PUID:PGID specified in .env
- **Security**: Enhanced security with no-new-privileges and resource constraints
- **Monitoring**: Built-in health checks for all services
- **Logging**: Centralized logging with Loki for all services
- **Updates**: Automated updates via Watchtower

## Service Ports

When all services are running, these ports will be available on localhost:

### Core Services
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

### Monitoring & Logging
- Glances: 61208
- Uptime-Kuma: 3001
- Dozzle: 9999
- AdGuard Home: 3000 (first-run), 53 (DNS)
- **Grafana**: 3000
- **Prometheus**: 9090
- **Node Exporter**: 9100
- **cAdvisor**: 8080
- **Loki**: 3100

## Health Check Endpoints

Each service exposes a health check endpoint for monitoring:

- **Plex**: `http://127.0.0.1:32400/web/index.html`
- **n8n**: `http://127.0.0.1:5678/healthz`
- **Sonarr**: `http://127.0.0.1:8989/health`
- **Radarr**: `http://127.0.0.1:7878/health`
- **Homarr**: `http://127.0.0.1:7575/api/health`
- **Portainer**: `http://127.0.0.1:9000/api/status`
- **Gluetun**: `http://127.0.0.1:8080/v1/openvpn/status`
- **qBittorrent**: `http://127.0.0.1:8080/api/v2/app/version`
- **Prowlarr**: `http://127.0.0.1:9696/health`
- **Bazarr**: `http://127.0.0.1:6767/health`
- **Overseerr**: `http://127.0.0.1:5055/health`
- **Tautulli**: `http://127.0.0.1:8181/status`
- **Glances**: `http://127.0.0.1:61208/api/3/status`
- **Uptime-Kuma**: `http://127.0.0.1:3001/`
- **Dozzle**: `http://127.0.0.1:9999/`
- **AdGuard Home**: `http://127.0.0.1:3000/control/status`

## Monitoring & Logging Access

### Grafana Dashboards
- **URL**: `http://localhost:3000` or `https://grafana.rolandgeorge.me`
- **Default**: admin / admin_change_me
- **Features**: Log queries, metrics dashboards, alerting

### Prometheus Metrics
- **URL**: `http://localhost:9090` or `https://prometheus.rolandgeorge.me`
- **Features**: Metrics collection, querying, alerting rules

### Loki Logs
- **URL**: `http://localhost:3100` or `https://loki.rolandgeorge.me`
- **Features**: Log aggregation, search, filtering

### Watchtower Configuration
Configure notifications in `.env`:
```bash
# Discord example
SHOUTRRR_URL=discord://webhook_id/webhook_token

# Slack example  
SHOUTRRR_URL=slack://token-a/token-b/token-c

# Email example
SHOUTRRR_URL=smtp://username:password@host:port/?from=fromaddress&to=recipient@example.com
```

## Service URLs

All services are accessible via HTTPS subdomains:

| Service | URL | Purpose |
|---------|-----|---------|
| Plex | `https://plex.rolandgeorge.me` | Media server |
| Homarr | `https://dash.rolandgeorge.me` | Dashboard |
| Portainer | `https://portainer.rolandgeorge.me` | Docker management |
| Grafana | `https://grafana.rolandgeorge.me` | Monitoring dashboards |
| Prometheus | `https://prometheus.rolandgeorge.me` | Metrics collection |
| Loki | `https://loki.rolandgeorge.me` | Log aggregation |
| Node Metrics | `https://metrics.rolandgeorge.me` | System metrics |
