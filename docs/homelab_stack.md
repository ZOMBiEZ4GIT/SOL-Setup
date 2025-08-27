# SOL Homelab Stack - As-Built Documentation

## Overview

The SOL homelab is a comprehensive media and automation stack running on Ubuntu Server (2018 MacBook Pro) using Docker Compose v2. The stack provides media management, automation, monitoring, and network services all accessible via Cloudflare Tunnel.

## Service Breakdown

### Core Infrastructure

#### Cloudflare Tunnel (cloudflared)
- **Purpose**: Secure external access to services without port forwarding
- **Image**: `cloudflare/cloudflared:latest`
- **Network**: Host mode (to reach 127.0.0.1 services)
- **Configuration**: Local-config mode with ingress mapping
- **Subdomains**: All services exposed on `*.rolandgeorge.me`

#### AdGuard Home (adguardhome)
- **Purpose**: Network-wide DNS filtering and ad blocking
- **Image**: `adguard/adguardhome:latest`
- **Ports**: 53 (DNS), 3000 (first-run admin UI)
- **Network**: Host mode (for DNS port binding)
- **Subdomain**: `dns.rolandgeorge.me`
- **Volumes**: `./adguard/work`, `./adguard/conf`

### Media Pipeline

#### Plex (plex)
- **Purpose**: Media server for movies and TV shows
- **Image**: `lscr.io/linuxserver/plex:latest`
- **Port**: 32400
- **Network**: Host mode (for local discovery)
- **Subdomain**: `plex.rolandgeorge.me`
- **Volumes**: `/srv/media` (movies/tv), `./plex/config`

#### Sonarr (sonarr)
- **Purpose**: TV show management and automation
- **Image**: `lscr.io/linuxserver/sonarr:latest`
- **Port**: 8989
- **Subdomain**: `sonarr.rolandgeorge.me`
- **Volumes**: `/srv/media/tv`, `/srv/downloads`, `./sonarr/config`

#### Radarr (radarr)
- **Purpose**: Movie management and automation
- **Image**: `lscr.io/linuxserver/radarr:latest`
- **Port**: 7878
- **Subdomain**: `radarr.rolandgeorge.me`
- **Volumes**: `/srv/media/movies`, `/srv/downloads`, `./radarr/config`

#### qBittorrent (qbittorrent) + Gluetun VPN
- **Purpose**: Secure torrent downloading via ProtonVPN
- **Images**: `lscr.io/linuxserver/qbittorrent:latest`, `qmcgaw/gluetun:latest`
- **Port**: 8080 (published via gluetun)
- **Network**: qBittorrent uses `service:gluetun` network mode
- **Subdomain**: `qbit.rolandgeorge.me`
- **VPN**: ProtonVPN via OpenVPN (configured in gluetun)
- **Volumes**: `/srv/downloads`, `./qbittorrent/config`

#### Prowlarr (prowlarr)
- **Purpose**: Indexer management for Sonarr/Radarr
- **Image**: `lscr.io/linuxserver/prowlarr:latest`
- **Port**: 9696
- **Subdomain**: `prowlarr.rolandgeorge.me`
- **Volumes**: `./prowlarr/config`

#### Bazarr (bazarr)
- **Purpose**: Subtitle management for movies and TV
- **Image**: `lscr.io/linuxserver/bazarr:latest`
- **Port**: 6767
- **Subdomain**: `bazarr.rolandgeorge.me`
- **Volumes**: `/srv/media/movies`, `/srv/media/tv`, `./bazarr/config`

#### Overseerr (overseerr)
- **Purpose**: Request management for Plex users
- **Image**: `sctx/overseerr:latest`
- **Port**: 5055
- **Subdomain**: `overseerr.rolandgeorge.me`
- **Volumes**: `./overseerr/config`

#### Tautulli (tautulli)
- **Purpose**: Plex analytics and monitoring
- **Image**: `lscr.io/linuxserver/tautulli:latest`
- **Port**: 8181
- **Subdomain**: `tautulli.rolandgeorge.me`
- **Volumes**: `./tautulli/config`, `./tautulli/logs`

### Automation & Workflow

#### n8n (n8n)
- **Purpose**: Workflow automation and integration
- **Image**: `n8nio/n8n:latest`
- **Port**: 5678
- **Subdomain**: `n8n.rolandgeorge.me`
- **Security**: Basic auth (admin/change_me_now)
- **Volumes**: `./n8n`

### Monitoring & Operations

#### Glances (glances)
- **Purpose**: System monitoring and metrics
- **Image**: `nicolargo/glances:latest`
- **Port**: 61208
- **Network**: Host PID mode for system access
- **Subdomain**: `glances.rolandgeorge.me`
- **Volumes**: Docker socket, `/proc`, `/sys`

#### Uptime-Kuma (uptime-kuma)
- **Purpose**: Service availability monitoring
- **Image**: `louislam/uptime-kuma:1`
- **Port**: 3001
- **Subdomain**: `status.rolandgeorge.me`
- **Volumes**: `./uptime-kuma/data`

#### Dozzle (dozzle)
- **Purpose**: Real-time Docker log viewer
- **Image**: `amir20/dozzle:latest`
- **Port**: 9999
- **Subdomain**: `logs.rolandgeorge.me`
- **Volumes**: Docker socket (read-only)

#### Portainer (portainer)
- **Purpose**: Docker management interface
- **Image**: `portainer/portainer-ce:latest`
- **Ports**: 9000 (HTTP), 9443 (HTTPS), 8000 (tunnel)
- **Subdomain**: `portainer.rolandgeorge.me`
- **Volumes**: Docker socket, `./portainer/data`

#### Homarr (homarr)
- **Purpose**: Homelab dashboard
- **Image**: `ghcr.io/ajnart/homarr:latest`
- **Port**: 7575
- **Subdomain**: `dash.rolandgeorge.me`
- **Volumes**: `./homarr/configs`, Docker socket

## Data Flows

### Media Pipeline Flow
1. **Prowlarr** → Manages indexers and provides search capabilities
2. **Sonarr/Radarr** → Search for content using Prowlarr indexers
3. **qBittorrent** (via Gluetun) → Downloads content to `/srv/downloads`
4. **Sonarr/Radarr** → Process completed downloads to `/srv/media`
5. **Plex** → Serves media from `/srv/media` to users
6. **Bazarr** → Downloads subtitles for content in `/srv/media`
7. **Overseerr** → Handles user requests for new content
8. **Tautulli** → Tracks Plex usage and analytics

### Monitoring & Operations Flow
- **Glances** → System resource monitoring
- **Uptime-Kuma** → Service availability checks
- **Dozzle** → Real-time log aggregation
- **Portainer** → Docker container management
- **Homarr** → Central dashboard for all services

### Access Flow
- **Cloudflared** runs in host mode with access to 127.0.0.1
- Ingress routes map each subdomain to local HTTP endpoints
- All services accessible via `https://*.rolandgeorge.me`

### DNS Flow
- **AdGuard Home** binds to host port 53 for network-wide DNS
- First-run setup UI available on port 3000
- May conflict with systemd-resolved (requires configuration)

## Environment Configuration

### Timezone
- All services configured for `Australia/Melbourne`
- Set via `TZ` environment variable

### User/Group IDs
- LinuxServer.io containers run as `PUID=1000` and `PGID=1000`
- Ensures proper file ownership on host volumes

### VPN Configuration
- **Primary**: OpenVPN with ProtonVPN
- **Alternative**: WireGuard (commented in env template)
- **Location**: Australia servers
- **Security**: Firewall rules and surveillance blocking enabled

## Storage Layout

### Host Directories
- `/srv/media/movies` → Movie storage for Plex/Radarr
- `/srv/media/tv` → TV show storage for Plex/Sonarr  
- `/srv/downloads` → Download staging area

### Container Data
- All application data stored in `./docker/<service>/`
- Excluded from git via `.gitignore`
- Included in backup scripts

## Network Architecture

### Port Assignments
- **32400**: Plex (host network)
- **8989**: Sonarr
- **7878**: Radarr
- **5678**: n8n
- **8080**: qBittorrent (via gluetun)
- **9000/9443**: Portainer
- **7575**: Homarr
- **9696**: Prowlarr
- **6767**: Bazarr
- **5055**: Overseerr
- **8181**: Tautulli
- **61208**: Glances
- **3001**: Uptime-Kuma
- **9999**: Dozzle
- **53/3000**: AdGuard Home

### External Access
- All HTTP services accessible via Cloudflare Tunnel
- No direct port forwarding required
- SSL termination handled by Cloudflare
