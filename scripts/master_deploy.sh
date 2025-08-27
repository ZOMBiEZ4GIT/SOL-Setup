#!/usr/bin/env bash
set -euo pipefail

# SOL Homelab Master Deploy Script
# Complete fresh deployment from clone to production-ready homelab
# This script handles everything: cleanup, setup, configuration, and deployment

# Version and metadata
SCRIPT_VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

# Show banner
show_banner() {
    echo -e "${CYAN}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                     SOL HOMELAB MASTER DEPLOY                ║
║               Complete Fresh Deployment Pipeline              ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    log "Master Deploy Script v${SCRIPT_VERSION}"
    log "This script will perform a complete fresh deployment from scratch"
    echo ""
}

# Check if we're in the right directory
check_working_directory() {
    step "Checking working directory..."
    
    if [ ! -f "$PROJECT_ROOT/Makefile" ]; then
        error "Must be run from SOL-Setup repository root"
        error "Expected: cd ~/SOL-Setup && bash scripts/master_deploy.sh"
        exit 1
    fi
    
    success "Working directory: $PROJECT_ROOT"
}

# Check for required dependencies
check_dependencies() {
    step "Checking system dependencies..."
    local missing_deps=()
    
    # Core dependencies
    for cmd in docker curl sed awk openssl grep; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    # Check docker compose (could be docker-compose or docker compose)
    if ! docker compose version &> /dev/null && ! docker-compose version &> /dev/null; then
        missing_deps+=("docker-compose")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        error "Missing required dependencies: ${missing_deps[*]}"
        error "Please install missing dependencies and try again"
        error ""
        error "On Ubuntu/Debian: sudo apt update && sudo apt install -y docker.io docker-compose-plugin curl sed gawk openssl grep"
        error "On RHEL/CentOS: sudo dnf install -y docker docker-compose curl sed gawk openssl grep"
        exit 1
    fi
    
    success "All dependencies available"
}

# Check Docker daemon
check_docker_daemon() {
    step "Checking Docker daemon..."
    
    # Check if Docker command exists
    if ! command -v docker &> /dev/null; then
        error "Docker not found. Please install Docker Desktop first."
        error "Download from: https://www.docker.com/products/docker-desktop/"
        exit 1
    fi
    
    # Check if Docker daemon is accessible
    local docker_attempts=0
    local max_attempts=30
    
    while [ $docker_attempts -lt $max_attempts ]; do
        if docker info &> /dev/null 2>&1; then
            break
        fi
        
        if [ $docker_attempts -eq 0 ]; then
            warn "Docker daemon not accessible"
            info "This usually means Docker Desktop isn't running yet"
            echo ""
            info "Please start Docker Desktop:"
            info "1. Open Docker Desktop application"
            info "2. Wait for it to show 'Engine running' (green indicator)"
            info "3. This script will wait up to 5 minutes for Docker to start"
            echo ""
            log "Waiting for Docker Desktop to start..."
        fi
        
        echo -ne "\rWaiting for Docker... ($((docker_attempts + 1))/$max_attempts) "
        sleep 10
        docker_attempts=$((docker_attempts + 1))
    done
    
    echo "" # New line after the waiting dots
    
    if ! docker info &> /dev/null 2>&1; then
        error "Docker daemon still not accessible after waiting"
        error "Please ensure Docker Desktop is running and try again"
        error ""
        error "Common solutions:"
        error "• Start Docker Desktop application"
        error "• Restart Docker Desktop if it's stuck"
        error "• Check Windows services for Docker Desktop Service"
        exit 1
    fi
    
    success "Docker daemon is running"
    
    # Determine compose command
    if docker compose version &> /dev/null 2>&1; then
        COMPOSE_CMD="docker compose"
    elif docker-compose version &> /dev/null 2>&1; then
        COMPOSE_CMD="docker-compose"
    else
        error "Neither 'docker compose' nor 'docker-compose' available"
        error "Please ensure Docker Desktop is properly installed"
        exit 1
    fi
    
    success "Docker Compose available (using: $COMPOSE_CMD)"
    
    # Install Loki logging plugin
    install_loki_plugin
}

# Install Loki logging plugin for Docker
install_loki_plugin() {
    step "Setting up Docker logging plugins..."
    
    # Check if Loki plugin is already installed
    if docker plugin ls | grep -q "loki"; then
        success "Loki logging plugin already installed"
        return 0
    fi
    
    log "Installing Loki logging driver plugin..."
    
    # Try to install the Loki logging plugin
    set +e  # Don't exit on error for plugin installation
    local plugin_install_output
    plugin_install_output=$(docker plugin install grafana/loki-docker-driver:latest --alias loki --grant-all-permissions 2>&1)
    local plugin_exit_code=$?
    set -e  # Re-enable exit on error
    
    if [ $plugin_exit_code -eq 0 ]; then
        success "Loki logging plugin installed successfully"
        
        # Always create the override file to fix pipeline-stages issue
        log "Creating Loki configuration override to fix pipeline-stages issue..."
        disable_loki_logging
    else
        warn "Failed to install Loki logging plugin"
        if echo "$plugin_install_output" | grep -q "already exists"; then
            warn "Plugin already exists - creating configuration override"
            disable_loki_logging
        else
            warn "Will deploy with standard Docker logging instead"
            warn "Plugin installation error: $plugin_install_output"
            
            # Create override to completely disable Loki logging
            create_no_loki_override
        fi
        return 0
    fi
}

# Create override to completely disable Loki logging
create_no_loki_override() {
    log "Creating override to disable Loki logging entirely..."
    
    cd "$PROJECT_ROOT/docker"
    
    cat > docker-compose.override.yml << 'EOF'
# Override to disable Loki logging entirely
# This file is auto-generated when Loki plugin is not available

services:
  # Disable Loki logging for all services by using default logging
  cloudflared:
    logging: {}
  adguardhome:
    logging: {}
  portainer:
    logging: {}
  homarr:
    logging: {}
  n8n:
    logging: {}
  watchtower:
    logging: {}
  plex:
    logging: {}
  sonarr:
    logging: {}
  radarr:
    logging: {}
  prowlarr:
    logging: {}
  bazarr:
    logging: {}
  overseerr:
    logging: {}
  tautulli:
    logging: {}
  gluetun:
    logging: {}
  qbittorrent:
    logging: {}
  glances:
    logging: {}
  uptime-kuma:
    logging: {}
  dozzle:
    logging: {}
  prometheus:
    logging: {}
  node-exporter:
    logging: {}
  cadvisor:
    logging: {}
  loki:
    logging: {}
  promtail:
    logging: {}
  grafana:
    logging: {}
EOF
    
    warn "Created docker-compose.override.yml to disable Loki logging"
    info "You can enable Loki logging later by removing this file and restarting services"
}

# Fix or disable Loki logging configuration
disable_loki_logging() {
    log "Fixing Loki logging configuration..."
    
    cd "$PROJECT_ROOT/docker"
    
    # Create a compose override to fix Loki logging configuration
    cat > docker-compose.override.yml << 'EOF'
# Override to fix Loki logging configuration
# This file is auto-generated to resolve Loki pipeline stage configuration issues

services:
  # Fix Loki logging for all services by removing problematic pipeline-stages
  cloudflared:
    logging:
      driver: "loki"
      options:
        loki-url: "http://loki:3100/loki/api/v1/push"
        loki-external-labels: "service=cloudflared,environment=homelab"
  
  adguardhome:
    logging:
      driver: "loki"
      options:
        loki-url: "http://loki:3100/loki/api/v1/push"
        loki-external-labels: "service=adguardhome,environment=homelab"
  
  portainer:
    logging:
      driver: "loki"
      options:
        loki-url: "http://loki:3100/loki/api/v1/push"
        loki-external-labels: "service=portainer,environment=homelab"
  
  homarr:
    logging:
      driver: "loki"
      options:
        loki-url: "http://loki:3100/loki/api/v1/push"
        loki-external-labels: "service=homarr,environment=homelab"
  
  n8n:
    logging:
      driver: "loki"
      options:
        loki-url: "http://loki:3100/loki/api/v1/push"
        loki-external-labels: "service=n8n,environment=homelab"
  
  watchtower:
    logging:
      driver: "loki"
      options:
        loki-url: "http://loki:3100/loki/api/v1/push"
        loki-external-labels: "service=watchtower,environment=homelab"
  
  plex:
    logging:
      driver: "loki"
      options:
        loki-url: "http://loki:3100/loki/api/v1/push"
        loki-external-labels: "service=plex,environment=homelab"
  
  sonarr:
    logging:
      driver: "loki"
      options:
        loki-url: "http://loki:3100/loki/api/v1/push"
        loki-external-labels: "service=sonarr,environment=homelab"
  
  radarr:
    logging:
      driver: "loki"
      options:
        loki-url: "http://loki:3100/loki/api/v1/push"
        loki-external-labels: "service=radarr,environment=homelab"
  
  prowlarr:
    logging:
      driver: "loki"
      options:
        loki-url: "http://loki:3100/loki/api/v1/push"
        loki-external-labels: "service=prowlarr,environment=homelab"
  
  bazarr:
    logging:
      driver: "loki"
      options:
        loki-url: "http://loki:3100/loki/api/v1/push"
        loki-external-labels: "service=bazarr,environment=homelab"
  
  overseerr:
    logging:
      driver: "loki"
      options:
        loki-url: "http://loki:3100/loki/api/v1/push"
        loki-external-labels: "service=overseerr,environment=homelab"
  
  tautulli:
    logging:
      driver: "loki"
      options:
        loki-url: "http://loki:3100/loki/api/v1/push"
        loki-external-labels: "service=tautulli,environment=homelab"
  
  gluetun:
    logging:
      driver: "loki"
      options:
        loki-url: "http://loki:3100/loki/api/v1/push"
        loki-external-labels: "service=gluetun,environment=homelab"
  
  qbittorrent:
    logging:
      driver: "loki"
      options:
        loki-url: "http://loki:3100/loki/api/v1/push"
        loki-external-labels: "service=qbittorrent,environment=homelab"
  
  glances:
    logging:
      driver: "loki"
      options:
        loki-url: "http://loki:3100/loki/api/v1/push"
        loki-external-labels: "service=glances,environment=homelab"
  
  uptime-kuma:
    logging:
      driver: "loki"
      options:
        loki-url: "http://loki:3100/loki/api/v1/push"
        loki-external-labels: "service=uptime-kuma,environment=homelab"
  
  dozzle:
    logging:
      driver: "loki"
      options:
        loki-url: "http://loki:3100/loki/api/v1/push"
        loki-external-labels: "service=dozzle,environment=homelab"
  
  prometheus:
    logging:
      driver: "loki"
      options:
        loki-url: "http://loki:3100/loki/api/v1/push"
        loki-external-labels: "service=prometheus,environment=homelab"
  
  node-exporter:
    logging:
      driver: "loki"
      options:
        loki-url: "http://loki:3100/loki/api/v1/push"
        loki-external-labels: "service=node-exporter,environment=homelab"
  
  cadvisor:
    logging:
      driver: "loki"
      options:
        loki-url: "http://loki:3100/loki/api/v1/push"
        loki-external-labels: "service=cadvisor,environment=homelab"
  
  loki:
    logging:
      driver: "loki"
      options:
        loki-url: "http://loki:3100/loki/api/v1/push"
        loki-external-labels: "service=loki,environment=homelab"
  
  promtail:
    logging:
      driver: "loki"
      options:
        loki-url: "http://loki:3100/loki/api/v1/push"
        loki-external-labels: "service=promtail,environment=homelab"
  
  grafana:
    logging:
      driver: "loki"
      options:
        loki-url: "http://loki:3100/loki/api/v1/push"
        loki-external-labels: "service=grafana,environment=homelab"
EOF
    
    warn "Created docker-compose.override.yml to fix Loki logging configuration"
    info "Removed problematic 'loki-pipeline-stages' option that was causing YAML parsing errors"
}

# Complete Docker cleanup
perform_docker_cleanup() {
    step "Performing complete Docker cleanup..."
    
    info "This will remove all containers, images, volumes, and networks"
    info "Press Ctrl+C within 10 seconds to cancel..."
    
    # Give user a chance to cancel
    for i in {10..1}; do
        echo -ne "\rProceeding in $i seconds... "
        sleep 1
    done
    echo ""
    
    log "Stopping all containers..."
    if docker ps -q | wc -l | grep -q "^0$"; then
        info "No running containers to stop"
    else
        docker stop $(docker ps -q) 2>/dev/null || true
    fi
    
    log "Removing all containers..."
    if docker ps -aq | wc -l | grep -q "^0$"; then
        info "No containers to remove"
    else
        docker rm $(docker ps -aq) 2>/dev/null || true
    fi
    
    log "Removing all images..."
    if docker images -q | wc -l | grep -q "^0$"; then
        info "No images to remove"
    else
        docker rmi $(docker images -q) 2>/dev/null || true
    fi
    
    log "Removing all volumes..."
    if docker volume ls -q | wc -l | grep -q "^0$"; then
        info "No volumes to remove"
    else
        docker volume rm $(docker volume ls -q) 2>/dev/null || true
    fi
    
    log "Removing all networks (except defaults)..."
    docker network ls --format "{{.Name}}" | grep -v -E '^(bridge|host|none)$' | xargs -r docker network rm 2>/dev/null || true
    
    log "Cleaning up Docker system..."
    docker system prune -af --volumes 2>/dev/null || true
    
    success "Docker cleanup completed"
}

# Create required directories
setup_directories() {
    step "Setting up required directories..."
    
    # Host directories for media and downloads
    log "Creating media directories..."
    sudo mkdir -p /srv/media/{movies,tv} /srv/downloads
    sudo chown -R $USER:$USER /srv
    
    # Docker data directories
    log "Creating Docker data directories..."
    cd "$PROJECT_ROOT/docker"
    
    # Create directories for persistent data
    mkdir -p {adguard/{work,conf},cloudflared,portainer,homarr/configs,n8n,watchtower}
    mkdir -p {plex,sonarr,radarr,prowlarr,bazarr,overseerr,tautulli,qbittorrent}/config
    mkdir -p {glances,uptime-kuma,dozzle}/data
    mkdir -p {prometheus/data,grafana/data,loki/data}
    
    # Set proper permissions
    chmod 755 cloudflared
    chmod 755 adguard/{work,conf}
    
    success "Directories created and configured"
}

# Setup basic environment file for initial deployment
setup_environment() {
    step "Setting up basic environment configuration..."
    
    cd "$PROJECT_ROOT/docker"
    
    if [ -f ".env" ]; then
        success "Found existing .env file"
        return 0
    fi
    
    log "Creating basic .env file from template..."
    cp env.template .env
    
    # Set basic defaults to avoid environment variable warnings
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s/N8N_PASSWORD=<generate_secure_password_here>/N8N_PASSWORD=changeme123/" .env
        sed -i '' "s/GRAFANA_ADMIN_PASSWORD=<generate_secure_password_here>/GRAFANA_ADMIN_PASSWORD=changeme123/" .env
    else
        # Linux
        sed -i "s/N8N_PASSWORD=<generate_secure_password_here>/N8N_PASSWORD=changeme123/" .env
        sed -i "s/GRAFANA_ADMIN_PASSWORD=<generate_secure_password_here>/GRAFANA_ADMIN_PASSWORD=changeme123/" .env
    fi
    
    success "Basic environment file created"
    
    warn "IMPORTANT: This .env file contains default/placeholder values"
    warn "Run 'make setup-env' after deployment to configure:"
    warn "  • Secure passwords"
    warn "  • VPN credentials" 
    warn "  • Custom timezone and user settings"
    echo ""
}

# Setup placeholder cloudflared configuration for local deployment
setup_cloudflared_config() {
    step "Setting up Cloudflared configuration..."
    
    cd "$PROJECT_ROOT/docker"
    
    # Check if config exists
    if [ ! -f "cloudflared/config.yml" ]; then
        log "Creating placeholder Cloudflare tunnel configuration..."
        
        # Create placeholder config for local-only deployment
        cat > cloudflared/config.yml << 'EOF'
# Cloudflare Tunnel Configuration - PLACEHOLDER
# This is a placeholder configuration for local deployment
# To enable external access via Cloudflare tunnels, run: make setup-tunnel

tunnel: <TUNNEL_UUID>
credentials-file: /etc/cloudflared/<TUNNEL_UUID>.json

# Ingress rules for all services
# These will work once tunnel is properly configured
ingress:
  - hostname: plex.rolandgeorge.me
    service: http://127.0.0.1:32400

  - hostname: sonarr.rolandgeorge.me
    service: http://127.0.0.1:8989
  - hostname: radarr.rolandgeorge.me
    service: http://127.0.0.1:7878
  - hostname: n8n.rolandgeorge.me
    service: http://127.0.0.1:5678
  - hostname: qbit.rolandgeorge.me
    service: http://127.0.0.1:8080
  - hostname: portainer.rolandgeorge.me
    service: http://127.0.0.1:9000
  - hostname: dash.rolandgeorge.me
    service: http://127.0.0.1:7575

  - hostname: prowlarr.rolandgeorge.me
    service: http://127.0.0.1:9696
  - hostname: bazarr.rolandgeorge.me
    service: http://127.0.0.1:6767
  - hostname: overseerr.rolandgeorge.me
    service: http://127.0.0.1:5055
  - hostname: tautulli.rolandgeorge.me
    service: http://127.0.0.1:8181
  - hostname: glances.rolandgeorge.me
    service: http://127.0.0.1:61208
  - hostname: status.rolandgeorge.me
    service: http://127.0.0.1:3001
  - hostname: logs.rolandgeorge.me
    service: http://127.0.0.1:9999

  # AdGuard first-run wizard on :3000
  - hostname: dns.rolandgeorge.me
    service: http://127.0.0.1:3000

  # Monitoring services
  - hostname: grafana.rolandgeorge.me
    service: http://127.0.0.1:3000
  - hostname: prometheus.rolandgeorge.me
    service: http://127.0.0.1:9090
  - hostname: metrics.rolandgeorge.me
    service: http://127.0.0.1:9100
  - hostname: loki.rolandgeorge.me
    service: http://127.0.0.1:3100

  - service: http_status:404
EOF
        
        success "Created placeholder Cloudflare config"
        info "Services will be accessible locally (http://localhost:XXXX)"
        info "To enable external access later, run: make setup-tunnel"
    else
        success "Found existing Cloudflare configuration"
        
        # Check if it's still a placeholder
        if grep -q "<TUNNEL_UUID>" cloudflared/config.yml; then
            warn "Cloudflare tunnel not yet configured (using placeholder)"
            info "Services will only be accessible locally"
            info "To enable external access, run: make setup-tunnel"
        else
            success "Cloudflare tunnel appears to be configured"
        fi
    fi
}

# Validate Docker Compose configuration
validate_configuration() {
    step "Validating Docker Compose configuration..."
    
    cd "$PROJECT_ROOT/docker"
    
    if ! $COMPOSE_CMD config >/dev/null 2>&1; then
        error "Docker Compose configuration has errors:"
        $COMPOSE_CMD config
        exit 1
    fi
    
    success "Docker Compose configuration is valid"
}

# Pull all required images
pull_images() {
    step "Pulling latest container images..."
    
    cd "$PROJECT_ROOT/docker"
    
    log "This may take several minutes depending on your internet connection..."
    
    if $COMPOSE_CMD pull; then
        success "All images pulled successfully"
    else
        error "Failed to pull some images"
        warn "Continuing with deployment - missing images will be pulled as needed"
    fi
}

# Deploy all services
deploy_services() {
    step "Deploying all services..."
    
    cd "$PROJECT_ROOT/docker"
    
    log "Starting all services in detached mode..."
    
    if $COMPOSE_CMD up -d; then
        success "Services deployed successfully"
    else
        error "Failed to deploy services"
        
        log "Checking for common issues..."
        
        # Check for port 53 conflict (AdGuard)
        if $COMPOSE_CMD logs adguardhome 2>/dev/null | grep -i "bind.*:53.*address already in use" >/dev/null 2>&1; then
            error "AdGuard Home cannot bind to port 53 (DNS conflict)"
            warn "Fix with: sudo sed -i 's/^#\\?DNSStubListener=.*/DNSStubListener=no/' /etc/systemd/resolved.conf"
            warn "Then: sudo systemctl restart systemd-resolved"
        fi
        
        exit 1
    fi
}

# Start cloudflared service (with placeholder config)
setup_cloudflared() {
    step "Starting Cloudflared service..."
    
    cd "$PROJECT_ROOT/docker"
    
    # Check if cloudflared should be started
    if grep -q "<TUNNEL_UUID>" cloudflared/config.yml; then
        warn "Cloudflared tunnel not configured - starting in placeholder mode"
        warn "Service will not be accessible externally until tunnel is configured"
        info "Run 'make setup-tunnel' after deployment to configure external access"
        
        # Don't start cloudflared with placeholder config as it will fail
        log "Skipping cloudflared startup (placeholder configuration)"
        return 0
    fi
    
    log "Starting cloudflared with configured tunnel..."
    $COMPOSE_CMD restart cloudflared
    
    # Wait for cloudflared to stabilize
    sleep 10
    
    log "Checking cloudflared tunnel status..."
    local logs_output
    logs_output=$($COMPOSE_CMD logs --tail=20 cloudflared 2>/dev/null || echo "")
    
    if echo "$logs_output" | grep -i "route propagating\|tunnel running" >/dev/null; then
        success "Cloudflared tunnel is running and routes are propagating"
    else
        warn "Cloudflared may need configuration - check logs: make logs"
        info "Recent cloudflared logs:"
        echo "$logs_output" | tail -10
    fi
}

# Perform health checks
perform_health_checks() {
    step "Performing system health checks..."
    
    cd "$PROJECT_ROOT/docker"
    
    # Wait for services to stabilize
    log "Waiting for services to stabilize..."
    sleep 15
    
    # Check running containers
    local running_containers total_services
    running_containers=$($COMPOSE_CMD ps --services --filter "status=running" | wc -l)
    total_services=$($COMPOSE_CMD ps --services | wc -l)
    
    if [ "$running_containers" -eq "$total_services" ]; then
        success "All $total_services services are running healthy"
    else
        warn "Only $running_containers of $total_services services are running"
        
        # Show status
        log "Service status:"
        $COMPOSE_CMD ps
        
        # Check failed services
        local failed_services
        failed_services=$($COMPOSE_CMD ps --services --filter "status=exited" | head -3)
        
        if [ -n "$failed_services" ]; then
            warn "Failed services detected. Recent logs:"
            while IFS= read -r service; do
                if [ -n "$service" ]; then
                    echo "--- $service ---"
                    $COMPOSE_CMD logs --tail=5 "$service" 2>/dev/null || echo "No logs available"
                fi
            done <<< "$failed_services"
        fi
    fi
}

# Show deployment summary and next steps
show_deployment_summary() {
    step "Deployment Summary"
    
    echo -e "${GREEN}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                    🎉 DEPLOYMENT COMPLETE! 🎉                ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    success "SOL Homelab has been successfully deployed!"
    
    echo ""
    info "Service Access URLs:"
    echo "===================="
    
    # Local access
    echo -e "${CYAN}Local Network:${NC}"
    echo "  🏠 Homarr Dashboard: http://localhost:7575"
    echo "  🐳 Portainer: http://localhost:9000"
    echo "  🎬 Plex: http://localhost:32400"
    echo "  📺 Sonarr: http://localhost:8989"
    echo "  🎭 Radarr: http://localhost:7878"
    echo "  🔍 Prowlarr: http://localhost:9696"
    echo "  📝 Bazarr: http://localhost:6767"
    echo "  🎫 Overseerr: http://localhost:5055"
    echo "  📊 Tautulli: http://localhost:8181"
    echo "  ⬇️  qBittorrent: http://localhost:8080"
    echo "  🛡️  AdGuard Home: http://localhost:3000"
    echo "  🔧 n8n: http://localhost:5678"
    echo "  📈 Grafana: http://localhost:3000"
    echo ""
    
    # External access status
    echo -e "${CYAN}External Access Status:${NC}"
    if [ -f "docker/cloudflared/config.yml" ] && ! grep -q "<TUNNEL_UUID>" docker/cloudflared/config.yml; then
        echo "  ✅ Configured - Services accessible via:"
        grep -E "^\s*-\s*hostname:" docker/cloudflared/config.yml | sed 's/.*hostname: */     🌐 https:\/\//' | head -5
        echo "     ... and more!"
    else
        echo "  ⚠️  Not configured - Services only accessible locally"
        echo "     Run 'make setup-tunnel' to enable external access"
    fi
    echo ""
    
    echo -e "${YELLOW}Generated Credentials:${NC}"
    echo "====================="
    if [ -f "docker/.env" ]; then
        echo "  👤 n8n Admin:"
        echo "     User: $(grep "^N8N_USER=" docker/.env | cut -d'=' -f2)"
        echo "     Password: $(grep "^N8N_PASSWORD=" docker/.env | cut -d'=' -f2)"
        echo ""
        echo "  📊 Grafana Admin:"
        echo "     User: admin"
        echo "     Password: $(grep "^GRAFANA_ADMIN_PASSWORD=" docker/.env | cut -d'=' -f2)"
        echo ""
    fi
    
    echo -e "${PURPLE}Next Steps:${NC}"
    echo "==========="
    echo "  1. 🔐 Configure environment: make setup-env (passwords, VPN, etc.)"
    echo "  2. 🌐 Setup external access: make setup-tunnel (optional)"
    echo "  3. 🔧 Configure services: make configure-services (optional)"
    echo "  4. 📊 Check service status: make status"
    echo "  5. 📝 View logs: make logs"
    echo "  6. 💾 Create backup: make backup"
    echo ""
    
    echo -e "${GREEN}Useful Commands:${NC}"
    echo "==============="
    echo "  make setup-tunnel        - Setup external access via Cloudflare"
    echo "  make status              - Check service status"
    echo "  make logs                - View cloudflared logs"
    echo "  make backup              - Create system backup"
    echo "  make validate            - Validate configuration"
    echo "  make restart GROUP=all   - Restart all services"
    echo ""
    
    warn "IMPORTANT NOTES:"
    warn "  • This is a BASIC deployment with default/placeholder configuration"
    warn "  • Services use default passwords (changeme123) - NOT secure for production"
    warn "  • VPN services will not work until credentials are configured"
    warn "  • Services are LOCAL ONLY until external access is configured"
    warn "  • Docker Desktop must remain running for services to work"
    warn "  • Run the setup scripts above to complete configuration"
    warn "  • Backup after full configuration: git add -A && git commit -m 'deploy: $(date +%Y%m%d-%H%M)'"
    
    # Check if override file was created
    if [ -f "docker/docker-compose.override.yml" ]; then
        echo ""
        warn "LOGGING NOTICE:"
        if grep -q "loki-url" docker/docker-compose.override.yml; then
            warn "  • Loki logging configuration has been fixed"
            warn "  • Removed problematic 'loki-pipeline-stages' option"
            warn "  • Centralized logging should work correctly"
            warn "  • Override file: docker/docker-compose.override.yml"
        else
            warn "  • Loki logging plugin could not be installed"
            warn "  • Services are using standard Docker logging instead"
            warn "  • Centralized logging via Loki service may not work optimally"
            warn "  • Remove docker/docker-compose.override.yml and restart to re-enable"
        fi
    fi
    
    echo ""
    success "Master deployment (core infrastructure) completed successfully!"
    info "🦴 The 'bones' of your SOL Homelab are now running! 🦴"
    info "📋 Run the setup scripts above to complete configuration 📋"
}

# Main deployment pipeline
main() {
    show_banner
    
    # Pre-flight checks
    check_working_directory
    check_dependencies
    check_docker_daemon
    
    # Cleanup and preparation
    perform_docker_cleanup
    setup_directories
    setup_environment
    
    # Configuration validation
    setup_cloudflared_config
    validate_configuration
    
    # Deployment
    pull_images
    deploy_services
    setup_cloudflared
    
    # Post-deployment
    perform_health_checks
    show_deployment_summary
    
    success "🎉 Master deployment completed successfully! 🎉"
}

# Handle script interruption
cleanup_on_exit() {
    error "Deployment interrupted"
    warn "You may need to run: docker system prune -af"
    exit 1
}

trap cleanup_on_exit INT TERM

# Parse command line arguments
SKIP_CLEANUP=false
QUIET=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-cleanup)
            SKIP_CLEANUP=true
            shift
            ;;
        --quiet)
            QUIET=true
            shift
            ;;
        --help|-h)
            echo "SOL Homelab Master Deploy Script"
            echo ""
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --skip-cleanup    Skip Docker cleanup phase"
            echo "  --quiet          Reduce output verbosity"
            echo "  --help, -h       Show this help message"
            echo ""
            echo "This script performs a complete fresh deployment of SOL Homelab"
            echo "including Docker cleanup, environment setup, and service deployment."
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            error "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Skip cleanup if requested
if [ "$SKIP_CLEANUP" = true ]; then
    warn "Skipping Docker cleanup as requested"
    # Override cleanup function
    perform_docker_cleanup() {
        step "Skipping Docker cleanup (--skip-cleanup flag provided)"
        info "Using existing Docker state"
    }
fi

# Run the main deployment pipeline
main "$@"

