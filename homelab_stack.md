# Roland's Homelab Stack

## Media Services
- **Plex** (`plex.rolandgeorge.me`)
  - Media server, accessible remotely via Cloudflare Tunnel
  - Network mode: host (for DLNA/discovery)
  - Volumes: `/srv/media`
  - Used by Overseerr and Tautulli

- **Sonarr** (`sonarr.rolandgeorge.me`)
  - Automates TV downloads and management
  - Port: 8989
  - Volumes: `/srv/media/tv`, `/srv/downloads`
  - Integrates with Prowlarr and qBittorrent

- **Radarr** (`radarr.rolandgeorge.me`)
  - Automates movie downloads and management
  - Port: 7878
  - Volumes: `/srv/media/movies`, `/srv/downloads`
  - Integrates with Prowlarr and qBittorrent

- **Bazarr** (`bazarr.rolandgeorge.me`)
  - Subtitle management
  - Port: 6767
  - Volumes: `/srv/media/movies`, `/srv/media/tv`
  - Integrates with Sonarr and Radarr

- **Prowlarr** (`prowlarr.rolandgeorge.me`)
  - Indexer manager
  - Port: 9696
  - Syncs indexers with Sonarr and Radarr

- **Overseerr** (`overseerr.rolandgeorge.me`)
  - Media requests management
  - Port: 5055
  - Integrates with Plex, Sonarr, and Radarr

- **Tautulli** (`tautulli.rolandgeorge.me`)
  - Plex analytics and activity monitoring
  - Port: 8181
  - Uses Plex logs

- **qBittorrent** (`qbit.rolandgeorge.me`)
  - Torrent client
  - Routed through ProtonVPN via Gluetun
  - WebUI: 8080 (exposed by Gluetun)
  - Volumes: `/srv/downloads`

- **Gluetun (ProtonVPN)**
  - VPN container for qBittorrent
  - Publishes ports: 8080, 51413/tcp, 51413/udp
  - Ensures torrent traffic is tunneled securely

---

## Dashboards & Management
- **Homarr** (`dash.rolandgeorge.me`)
  - Dashboard for shortcuts and widgets
  - Port: 7575

- **Portainer** (`portainer.rolandgeorge.me`)
  - Docker management UI
  - Ports: 9000 (HTTP), 9443 (HTTPS)

- **Dozzle** (`logs.rolandgeorge.me`)
  - Pretty log viewer for containers
  - Port: 9999

- **Glances** (`glances.rolandgeorge.me`)
  - System monitoring (CPU, RAM, disk, network)
  - Port: 61208

- **Uptime Kuma** (`status.rolandgeorge.me`)
  - Service uptime monitoring
  - Port: 3001

---

## Network & Infrastructure
- **Cloudflared**
  - Cloudflare Tunnel client
  - Routes all subdomains securely to services
  - Network: host
  - Config: `~/docker/cloudflared/config.yml`

- **AdGuard Home** (`dns.rolandgeorge.me`)
  - Network-wide ad and tracker blocking
  - Network: host (binds port 53)
  - Admin UI: 3000 (initial setup), can move to 80/443 later

---

## Media Automation Flow
Prowlarr (indexers) → Sonarr/Radarr (media automation) → qBittorrent (downloads, through ProtonVPN) → Plex (library) → Bazarr (subtitles) → Overseerr (requests) → Tautulli (analytics).

---

## Monitoring & Management Flow
- **Glances** for system health
- **Uptime Kuma** for service availability
- **Dozzle** for logs
- **Portainer** for container management
- **Homarr** as the central dashboard

---

## Next Steps / Future Ideas
- Integrate Cloudflare Access for sensitive apps (qBittorrent, Portainer, AdGuard)
- Explore Immich for photo backup
- Add Paperless-ngx for document management
- Add Grafana + Prometheus for advanced observability
