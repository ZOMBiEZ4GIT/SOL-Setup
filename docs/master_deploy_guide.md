# Master Deploy Guide

## Overview

The **Master Deploy Script** (`scripts/master_deploy.sh`) is a comprehensive deployment automation tool that handles the complete setup of your SOL Homelab from a fresh clone to a fully operational system.

## What It Does

The master deploy script performs these operations in sequence:

1. **🧹 Complete Docker Cleanup**
   - Stops all running containers
   - Removes all containers, images, volumes, and networks
   - Performs system cleanup (`docker system prune -af`)

2. **📁 Directory Setup**
   - Creates required host directories (`/srv/media`, `/srv/downloads`)
   - Sets up Docker data directories for all services
   - Configures proper permissions

3. **🔐 Environment Configuration**
   - Creates `.env` file from template
   - Generates secure passwords for all services
   - Creates backup encryption key

4. **☁️ Cloudflared Validation**
   - Validates tunnel configuration
   - Checks for credentials files
   - Ensures UUIDs match between config files

5. **🚀 Service Deployment**
   - Pulls all latest container images
   - Deploys all services via Docker Compose
   - Configures Cloudflare tunnels

6. **✅ Health Checks**
   - Validates all services are running
   - Reports any failed services
   - Shows deployment summary

## Usage

### Quick Start (Recommended)

```bash
# Clone the repository
git clone <your-repo-url> SOL-Setup
cd SOL-Setup

# Run master deployment
make master-deploy
```

### Alternative Usage

```bash
# Direct script execution
bash scripts/master_deploy.sh

# Skip Docker cleanup (if you want to preserve existing containers)
make master-deploy-skip-cleanup
# or
bash scripts/master_deploy.sh --skip-cleanup

# Show help
bash scripts/master_deploy.sh --help
```

## Prerequisites

### System Requirements

- **Operating System**: Linux (Ubuntu/Debian recommended)
- **Docker**: Docker Engine 20.10+ and Docker Compose v2
- **Network**: Internet connection for pulling images
- **Storage**: At least 20GB free space
- **Permissions**: Sudo access for directory creation

### Required Dependencies

The script will check for these dependencies and guide you to install missing ones:

- `docker` and `docker compose`
- `curl`
- `sed`, `awk`, `grep`
- `openssl`

### Before Running

1. **Set up Cloudflare tunnel** (if not already done):
   ```bash
   cd docker/cloudflared
   docker run --rm -v $(pwd):/root/.cloudflared cloudflare/cloudflared:latest tunnel login
   docker run --rm -v $(pwd):/root/.cloudflared cloudflare/cloudflared:latest tunnel create my-homelab
   ```

2. **Update configuration files** with your tunnel UUID:
   - `docker/cloudflared/config.yml`
   - `docker/services/infrastructure.yml`

## What Gets Created

### Generated Files

- `docker/.env` - Environment variables with secure passwords
- `.backup_password` - Encryption key for backups

### Directory Structure

```
/srv/
├── media/
│   ├── movies/
│   └── tv/
└── downloads/

docker/
├── adguard/{work,conf}/
├── cloudflared/
├── portainer/
├── homarr/configs/
├── n8n/
├── {plex,sonarr,radarr,prowlarr,bazarr,overseerr,tautulli,qbittorrent}/config/
├── {glances,uptime-kuma,dozzle}/data/
└── {prometheus/data,grafana/data,loki/data}/
```

### Generated Credentials

The script generates secure passwords for:

- **n8n**: Admin user credentials
- **Grafana**: Admin password
- **Backup**: Encryption key

## Post-Deployment

After successful deployment, you'll see:

### Local Service URLs

- 🏠 Homarr Dashboard: http://localhost:7575
- 🐳 Portainer: http://localhost:9000
- 🎬 Plex: http://localhost:32400
- 📺 Sonarr: http://localhost:8989
- 🎭 Radarr: http://localhost:7878
- And many more...

### External URLs (via Cloudflare)

All services configured in `cloudflared/config.yml` will be accessible via their hostnames.

### Next Steps

1. **Configure VPN**: Update `docker/.env` with your VPN credentials
2. **Test Services**: Access each service and complete initial setup
3. **Security**: Review generated passwords and update if needed
4. **Backup**: Create your first backup with `make backup`

## Troubleshooting

### Common Issues

1. **Port 53 conflict (AdGuard)**:
   ```bash
   sudo sed -i 's/^#\?DNSStubListener=.*/DNSStubListener=no/' /etc/systemd/resolved.conf
   sudo systemctl restart systemd-resolved
   docker compose restart adguardhome
   ```

2. **Cloudflared not connecting**:
   - Verify tunnel UUID in both config files
   - Check credentials file exists
   - Ensure DNS routes are configured in Cloudflare dashboard

3. **Services not starting**:
   ```bash
   make status  # Check service status
   make logs    # View logs
   ```

### Getting Help

```bash
# Check service status
make status

# View logs for specific service
docker compose logs -f servicename

# Restart all services
make restart GROUP=all

# Validate configuration
make validate
```

## Security Notes

- The `.env` file contains sensitive passwords - never commit it to git
- Backup your `.env` file and `.backup_password` securely
- Generated passwords are cryptographically secure (24-32 characters)
- All containers run with security constraints where possible

## Script Options

| Option | Description |
|--------|-------------|
| `--skip-cleanup` | Skip Docker cleanup phase |
| `--quiet` | Reduce output verbosity |
| `--help` | Show help message |

## Recovery

If something goes wrong during deployment:

1. **Check logs**: The script provides detailed error messages
2. **Manual cleanup**: Run `docker system prune -af` to clean up
3. **Retry**: Fix the issue and re-run the script
4. **Partial deployment**: Use `--skip-cleanup` to avoid re-downloading images

The script is designed to be idempotent - you can run it multiple times safely.
