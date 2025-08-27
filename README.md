# SOL Homelab - Production Docker Stack - By Roland

A production-ready homelab setup running on Ubuntu with Docker Compose, featuring media management, automation, monitoring, and secure external access via Cloudflare Tunnel.

## Overview

The SOL homelab provides a comprehensive self-hosted infrastructure including:

- **Media Pipeline**: Plex, Sonarr, Radarr, qBittorrent (via VPN), Prowlarr, Bazarr, Overseerr, Tautulli
- **Automation**: n8n workflow automation
- **Monitoring**: Glances, Uptime-Kuma, Dozzle, Portainer, Homarr dashboard  
- **Network Services**: AdGuard Home DNS filtering
- **Secure Access**: Cloudflare Tunnel with local-config mode

All services are accessible via `*.rolandgeorge.me` subdomains with automatic SSL termination.

## Repository Structure

```
SOL-Setup/
├── docker/                    # Docker Compose stack
│   ├── docker-compose.yml     # Main service definitions
│   ├── env.template           # Environment template
│   ├── cloudflared/           # Tunnel configuration
│   ├── services/              # Future service split (scaffold)
│   └── README_docker.md       # Docker usage guide
├── scripts/                   # Operational scripts
│   ├── validate.sh            # Pre-deployment validation
│   ├── deploy.sh              # Deployment automation
│   ├── backup.sh              # Data backup
│   └── rollback.sh            # Rollback to last-good
├── docs/                      # Documentation
│   ├── homelab_stack.md       # As-built architecture
│   ├── SOP_add_service.md     # Adding new services
│   └── prompts/               # Master prompts for automation
├── Makefile                   # Convenience targets
├── .gitignore                 # Exclude secrets & data
└── README.md                  # This file
```

## Quick Start

```bash
# Clone and setup
git clone <your-repo-url> ~/SOL-Setup
cd ~/SOL-Setup && chmod +x scripts/*.sh

# Validate and deploy
make validate
make deploy

# Monitor logs
make logs
```

---

## First-Time Setup Runbook

### 1. Clone Repository

```bash
git clone <your repo ssh url> ~/SOL-Setup
cd ~/SOL-Setup && chmod +x scripts/*.sh
```

### 2. Create Host Directories

```bash
sudo mkdir -p /srv/media/{movies,tv} /srv/downloads
sudo chown -R $USER:$USER /srv
```

### 3. Configure Environment

```bash
cd docker
cp env.template .env
# Edit .env and fill in your actual values:
# - ProtonVPN credentials  
# - User/Group IDs if different from 1000:1000
# - Timezone if not Australia/Melbourne
```

### 4. Setup Cloudflared Credentials (Local-Config)

Place tunnel credentials in `docker/cloudflared/`:

```bash
cd docker/cloudflared

# Login and get cert.pem
sudo docker run --rm -u root -v "$(pwd)":/root/.cloudflared cloudflare/cloudflared:latest tunnel login

# Create a new tunnel
sudo docker run --rm -u root -v "$(pwd)":/root/.cloudflared cloudflare/cloudflared:latest tunnel create sol-local

# OR if tunnel already exists:
sudo docker run --rm -u root -v "$(pwd)":/root/.cloudflared cloudflare/cloudflared:latest tunnel list
sudo docker run --rm -u root -v "$(pwd)":/root/.cloudflared cloudflare/cloudflared:latest tunnel download <TUNNEL_UUID>
```

**Update tunnel UUID** in:
- `docker/docker-compose.yml` (cloudflared command)
- `docker/cloudflared/config.yml` (tunnel + credentials-file)

### 5. Register DNS Hostnames

From the `docker/cloudflared/` directory:

```bash
for host in plex sonarr radarr n8n qbit portainer dash prowlarr bazarr overseerr tautulli glances status logs dns; do
  sudo docker run --rm -u root -v "$(pwd)":/root/.cloudflared \
    cloudflare/cloudflared:latest tunnel route dns sol-local "${host}.rolandgeorge.me"
done
```

### 6. Validate & Deploy

```bash
cd ~/SOL-Setup
bash scripts/validate.sh
bash scripts/deploy.sh
```

### 7. Verify Deployment

Check cloudflared logs for route propagation:
```bash
docker compose logs cloudflared | grep -i "route propagating"
```

Test key services:
- `https://plex.rolandgeorge.me` (Media server)
- `https://dash.rolandgeorge.me` (Homarr dashboard)
- `https://portainer.rolandgeorge.me` (Docker management)
- `https://dns.rolandgeorge.me` (AdGuard first-run setup)

### 8. Create Stable Tag

```bash
git add -A && git commit -m "deploy: initial homelab setup"
git tag -f last-good && git push --tags
```

---

## Operational Commands

### Makefile Targets

```bash
make validate    # Lint compose and check ports
make deploy      # Pull images and deploy stack  
make logs        # Follow logs from all services
make backup      # Create timestamped backup
make rollback    # Reset to last-good tag and redeploy
```

### Manual Operations

```bash
# Individual service management
cd docker
docker compose up -d servicename
docker compose restart servicename
docker compose logs -f servicename

# System maintenance
docker compose pull              # Update images
docker system prune -f           # Cleanup unused data
```

---

## Service Access

All services are accessible via HTTPS subdomains:

| Service | URL | Purpose |
|---------|-----|---------|
| Plex | `https://plex.rolandgeorge.me` | Media server |
| Homarr | `https://dash.rolandgeorge.me` | Dashboard |
| Portainer | `https://portainer.rolandgeorge.me` | Docker management |
| Sonarr | `https://sonarr.rolandgeorge.me` | TV automation |
| Radarr | `https://radarr.rolandgeorge.me` | Movie automation |
| qBittorrent | `https://qbit.rolandgeorge.me` | Torrent client |
| n8n | `https://n8n.rolandgeorge.me` | Workflow automation |
| Prowlarr | `https://prowlarr.rolandgeorge.me` | Indexer management |
| Bazarr | `https://bazarr.rolandgeorge.me` | Subtitle management |
| Overseerr | `https://overseerr.rolandgeorge.me` | Request management |
| Tautulli | `https://tautulli.rolandgeorge.me` | Plex analytics |
| Glances | `https://glances.rolandgeorge.me` | System monitoring |
| Uptime-Kuma | `https://status.rolandgeorge.me` | Uptime monitoring |
| Dozzle | `https://logs.rolandgeorge.me` | Log viewer |
| AdGuard | `https://dns.rolandgeorge.me` | DNS management |

---

## Troubleshooting

### Cloudflared "Permission Denied" Reading JSON

Fix ownership to uid 65532:
```bash
sudo chown -R 65532:65532 docker/cloudflared
sudo chmod 640 docker/cloudflared/*.json
```

### Error 1033 (DNS Points to Tunnel with No Live Route)

- Ensure cloudflared is running with the **same UUID** as DNS CNAME target
- Verify ingress contains the hostname in `cloudflared/config.yml`
- Restart cloudflared: `docker compose restart cloudflared`
- Re-run DNS route registration from credentials folder

### Error 502 Bad Gateway

**Service not listening locally:**
```bash
curl http://127.0.0.1:<port>  # Should respond
docker compose logs <service>  # Check for errors
```

**Port not published on host:**
- For normal services: Ensure ports section in docker-compose.yml
- For VPN services: Ensure port is published on gluetun, not the app

**HTTPS origin without TLS verification:**
Add to cloudflared config.yml:
```yaml
- hostname: service.rolandgeorge.me
  service: https://127.0.0.1:port
  originRequest:
    noTLSVerify: true
```

### AdGuard Fails to Bind Port 53

systemd-resolved conflict:
```bash
sudo sed -i 's/^#\?DNSStubListener=.*/DNSStubListener=no/' /etc/systemd/resolved.conf
sudo systemctl restart systemd-resolved
docker restart adguardhome
```

### qBittorrent Authentication Issues Behind Cloudflare

Set in qBittorrent config:
- `WebUI\HostHeaderValidation=false`
- `WebUI\CSRFProtection=true`

### VPN Connection Failed

Check gluetun logs:
```bash
docker compose logs gluetun | grep -E "(error|connected|disconnected)"
```

Verify ProtonVPN credentials in `.env` file.

### Container Permission Issues

Fix volume ownership:
```bash
sudo chown -R $USER:$USER docker/<service>/
```

Check PUID/PGID values in `.env` match your user:
```bash
id $USER  # Should match PUID:PGID in .env
```

---

## Security Considerations

- **No secrets in git**: All credentials in `.env` (gitignored)
- **VPN for torrents**: qBittorrent routed through ProtonVPN
- **DNS filtering**: AdGuard Home blocks ads/malware network-wide
- **Secure tunnel**: Cloudflare handles SSL/TLS termination
- **Container isolation**: Each service runs in isolated container
- **Minimal attack surface**: No direct port forwarding required

---

## Backup & Recovery

### Automated Backup

```bash
make backup  # Creates encrypted, timestamped archive with cloud storage
```

**Features:**
- **Compression**: Automatic gzip compression
- **Encryption**: AES-256-CBC encryption with secure password generation
- **Cloud Storage**: Automatic upload to Proton Drive
- **GitHub Backup**: Creates timestamped backup branches
- **Retention**: Configurable retention policies (default: 30 days)
- **Verification**: Automatic backup integrity verification

### Manual Backup

```bash
# Enhanced backup with all features
bash scripts/backup.sh

# Basic backup (legacy)
tar czf homelab_backup_$(date +%F).tgz \
  docker/*/config docker/cloudflared/config.yml docs
```

### Backup Configuration

Configure backup settings in `scripts/backup.sh`:
```bash
# Retention policy
RETENTION_DAYS=30

# Enable/disable features
ENCRYPT=true
PROTON_DRIVE_BACKUP=true
GITHUB_BACKUP=true

# Proton Drive configuration (requires rclone setup)
# GitHub repository for backup branches
GITHUB_REPO="your-username/your-backup-repo"
```

### Disaster Recovery

1. **Restore from local backup**:
   ```bash
   # Decrypt and extract
   openssl enc -d -aes-256-cbc -in homelab_backup_TIMESTAMP.tar.gz.enc \
     -out homelab_backup.tar.gz -pass file:.backup_password
   tar xzf homelab_backup.tar.gz
   ```

2. **Restore from Proton Drive**:
   ```bash
   rclone copy proton:homelab-backups/backup_file.tar.gz.enc ./
   # Then decrypt as above
   ```

3. **Restore from GitHub**:
   ```bash
   git fetch origin
   git checkout backup-TIMESTAMP
   # Copy files back to original locations
   ```

4. **Recreate tunnel credentials** in `docker/cloudflared/`

5. **Deploy**:
   ```bash
   make deploy
   ```

---

## Contributing

1. Follow the SOP in `docs/SOP_add_service.md` for new services
2. Use the master prompts in `docs/prompts/` for guided setup
3. Update documentation when adding services
4. Test thoroughly before committing
5. Tag stable deployments with `last-good`

## Support

- **Documentation**: See `docs/` directory for detailed guides
- **Architecture**: Review `docs/homelab_stack.md` for service details
- **Operations**: Follow `docs/SOP_add_service.md` for changes
- **Troubleshooting**: Check this README and service logs

---

**Repository**: SOL Homelab Production Stack  
**Platform**: Ubuntu Server with Docker Compose v2  
**Access**: Cloudflare Tunnel (local-config mode)  
**Domain**: `*.rolandgeorge.me`
