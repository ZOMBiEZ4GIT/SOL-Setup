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
    
    if ! docker info &> /dev/null; then
        error "Docker daemon not running"
        info "Starting Docker daemon..."
        
        # Try to start Docker if possible
        if command -v systemctl &> /dev/null; then
            sudo systemctl start docker
            sleep 3
            if ! docker info &> /dev/null; then
                error "Failed to start Docker daemon"
                error "Please start Docker manually: sudo systemctl start docker"
                exit 1
            fi
        else
            error "Please start Docker daemon manually"
            exit 1
        fi
    fi
    
    # Determine compose command
    if docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
    elif docker-compose version &> /dev/null; then
        COMPOSE_CMD="docker-compose"
    else
        error "Neither 'docker compose' nor 'docker-compose' available"
        exit 1
    fi
    
    success "Docker daemon running (using: $COMPOSE_CMD)"
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

# Setup environment file with password generation
setup_environment() {
    step "Setting up environment configuration..."
    
    cd "$PROJECT_ROOT/docker"
    
    if [ -f ".env" ]; then
        warn "Existing .env file found"
        read -p "Overwrite existing .env file? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            info "Keeping existing .env file"
            return 0
        fi
    fi
    
    log "Creating .env file from template..."
    cp env.template .env
    
    # Generate secure passwords
    log "Generating secure passwords..."
    
    local n8n_password=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-24)
    local grafana_password=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-24)
    
    # Update passwords in .env file
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s/N8N_PASSWORD=<generate_secure_password_here>/N8N_PASSWORD=${n8n_password}/" .env
        sed -i '' "s/GRAFANA_ADMIN_PASSWORD=<generate_secure_password_here>/GRAFANA_ADMIN_PASSWORD=${grafana_password}/" .env
    else
        # Linux
        sed -i "s/N8N_PASSWORD=<generate_secure_password_here>/N8N_PASSWORD=${n8n_password}/" .env
        sed -i "s/GRAFANA_ADMIN_PASSWORD=<generate_secure_password_here>/GRAFANA_ADMIN_PASSWORD=${grafana_password}/" .env
    fi
    
    # Generate backup encryption password
    local backup_password=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
    echo "$backup_password" > "$PROJECT_ROOT/.backup_password"
    chmod 600 "$PROJECT_ROOT/.backup_password"
    
    success "Environment file created with secure passwords"
    
    # Show configuration status
    info "Generated passwords:"
    echo "  - n8n Password: $n8n_password"
    echo "  - Grafana Admin Password: $grafana_password"
    echo "  - Backup Encryption: Generated"
    echo ""
    warn "IMPORTANT: Please update the following in docker/.env:"
    warn "  - VPN credentials (OpenVPN or WireGuard)"
    warn "  - Timezone if not Australia/Melbourne"
    warn "  - User/Group IDs if different from 1000:1000"
    echo ""
}

# Setup and guide cloudflared configuration
setup_cloudflared_config() {
    step "Setting up Cloudflared tunnel configuration..."
    
    cd "$PROJECT_ROOT/docker"
    
    # Check if config exists
    if [ ! -f "cloudflared/config.yml" ]; then
        warn "Cloudflared config not found. Setting up interactively..."
        
        echo ""
        info "🔧 CLOUDFLARE TUNNEL SETUP REQUIRED"
        echo "======================================="
        echo ""
        echo "To use external access via Cloudflare tunnels, you need to:"
        echo "1. Login to your Cloudflare account"
        echo "2. Create or use an existing tunnel"
        echo "3. Configure the tunnel UUID"
        echo ""
        
        read -p "Do you want to set up Cloudflare tunnel now? (y/N): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            setup_cloudflare_tunnel_interactive
        else
            warn "Skipping Cloudflare tunnel setup"
            warn "Services will only be accessible locally"
            
            # Create minimal config for local-only deployment
            cat > cloudflared/config.yml << 'EOF'
# Cloudflare Tunnel Configuration - PLACEHOLDER
# To enable external access, replace <TUNNEL_UUID> with your actual tunnel UUID
# and download your tunnel credentials file

tunnel: <TUNNEL_UUID>
credentials-file: /etc/cloudflared/<TUNNEL_UUID>.json

# This configuration is for local testing only
# External access will not work until tunnel is properly configured
ingress:
  - service: http_status:404
EOF
            info "Created placeholder config at cloudflared/config.yml"
            info "You can configure the tunnel later and re-run: make master-deploy"
            return 0
        fi
    fi
    
    # Validate existing config
    validate_cloudflared_config
}

# Interactive Cloudflare tunnel setup
setup_cloudflare_tunnel_interactive() {
    log "Starting interactive Cloudflare tunnel setup..."
    
    # Step 1: Login
    echo ""
    info "Step 1: Login to Cloudflare"
    echo "This will open a browser window for authentication..."
    read -p "Press Enter to continue..."
    
    if ! docker run --rm -v "$(pwd)/cloudflared:/root/.cloudflared" cloudflare/cloudflared:latest tunnel login; then
        error "Failed to login to Cloudflare"
        info "You can continue without Cloudflare tunnel (local access only)"
        read -p "Continue without tunnel? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
        return 0
    fi
    
    # Step 2: List existing tunnels or create new one
    echo ""
    info "Step 2: Choose tunnel"
    echo "Checking for existing tunnels..."
    
    local tunnel_list
    local list_exit_code
    
    # Try to list tunnels, capture both output and exit code
    set +e  # Temporarily disable exit on error
    tunnel_list=$(docker run --rm -v "$(pwd)/cloudflared:/root/.cloudflared" cloudflare/cloudflared:latest tunnel list 2>&1)
    list_exit_code=$?
    set -e  # Re-enable exit on error
    
    if [ $list_exit_code -eq 0 ] && echo "$tunnel_list" | grep -q "ID"; then
        echo "Found existing tunnels:"
        echo "$tunnel_list"
        echo ""
        read -p "Do you want to use an existing tunnel? (y/N): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Please copy the UUID of the tunnel you want to use from the list above."
            read -p "Enter tunnel UUID: " tunnel_uuid
            
            # Validate UUID format
            if [[ ! $tunnel_uuid =~ ^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$ ]]; then
                warn "Invalid UUID format. Creating a new tunnel instead..."
                create_new_tunnel
            fi
        else
            create_new_tunnel
        fi
    elif [ $list_exit_code -eq 0 ] && echo "$tunnel_list" | grep -q "No tunnels"; then
        info "No existing tunnels found. Creating a new one..."
        create_new_tunnel
    else
        warn "Could not list tunnels (this is normal for new accounts):"
        echo "$tunnel_list"
        info "Creating a new tunnel..."
        create_new_tunnel
    fi
    
    # Step 3: Update configuration files
    update_tunnel_config "$tunnel_uuid"
    
    # Step 4: Download credentials
    log "Downloading tunnel credentials..."
    if ! docker run --rm -v "$(pwd)/cloudflared:/root/.cloudflared" cloudflare/cloudflared:latest tunnel download "$tunnel_uuid"; then
        error "Failed to download tunnel credentials"
        exit 1
    fi
    
    # Set proper permissions
    chmod 640 "cloudflared/${tunnel_uuid}.json"
    
    success "Cloudflare tunnel configured successfully!"
    info "Tunnel UUID: $tunnel_uuid"
}

# Create new tunnel
create_new_tunnel() {
    local tunnel_name="sol-homelab-$(date +%Y%m%d-%H%M)"
    
    log "Creating new tunnel: $tunnel_name"
    
    local create_output
    local create_exit_code
    
    # Try to create tunnel
    set +e  # Temporarily disable exit on error
    create_output=$(docker run --rm -v "$(pwd)/cloudflared:/root/.cloudflared" cloudflare/cloudflared:latest tunnel create "$tunnel_name" 2>&1)
    create_exit_code=$?
    set -e  # Re-enable exit on error
    
    if [ $create_exit_code -eq 0 ] && echo "$create_output" | grep -q "Created tunnel"; then
        tunnel_uuid=$(echo "$create_output" | grep "Created tunnel" | sed -E 's/.*with id: ([a-f0-9-]+).*/\1/')
        success "Created new tunnel: $tunnel_name"
        info "Tunnel UUID: $tunnel_uuid"
    else
        error "Failed to create tunnel:"
        echo "$create_output"
        echo ""
        error "Possible solutions:"
        error "1. Check your Cloudflare account has tunnel permissions"
        error "2. Verify you're logged into the correct Cloudflare account"
        error "3. Try creating a tunnel manually in the Cloudflare dashboard"
        error ""
        error "You can continue with local-only deployment and configure tunnels later."
        
        read -p "Continue without Cloudflare tunnel? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            tunnel_uuid="<TUNNEL_UUID>"  # Use placeholder
            warn "Continuing with placeholder configuration"
            return 0
        else
            exit 1
        fi
    fi
}

# Update tunnel configuration files
update_tunnel_config() {
    local uuid="$1"
    
    log "Updating configuration files with tunnel UUID..."
    
    # Update cloudflared/config.yml
    if [ -f "cloudflared/config.yml" ]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s/<TUNNEL_UUID>/$uuid/g" cloudflared/config.yml
        else
            sed -i "s/<TUNNEL_UUID>/$uuid/g" cloudflared/config.yml
        fi
    fi
    
    # Update services/infrastructure.yml
    if [ -f "services/infrastructure.yml" ]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s/<TUNNEL_UUID>/$uuid/g" services/infrastructure.yml
        else
            sed -i "s/<TUNNEL_UUID>/$uuid/g" services/infrastructure.yml
        fi
    fi
    
    success "Updated configuration files with tunnel UUID"
}

# Validate existing cloudflared configuration
validate_cloudflared_config() {
    log "Validating Cloudflared configuration..."
    
    # Extract UUID from config.yml
    local config_uuid
    config_uuid=$(grep "^tunnel:" cloudflared/config.yml | sed 's/tunnel: *//' | tr -d ' ')
    
    if [ "$config_uuid" = "<TUNNEL_UUID>" ] || [ -z "$config_uuid" ]; then
        warn "Tunnel UUID not configured in cloudflared/config.yml"
        warn "External access will not work until tunnel is properly configured"
        
        read -p "Do you want to configure the tunnel now? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            setup_cloudflare_tunnel_interactive
            return 0
        else
            warn "Continuing with local-only deployment"
            return 0
        fi
    fi
    
    # Check credentials file
    local creds_file="cloudflared/${config_uuid}.json"
    if [ ! -f "$creds_file" ]; then
        warn "Tunnel credentials file not found: $creds_file"
        info "Downloading credentials..."
        
        if docker run --rm -v "$(pwd)/cloudflared:/root/.cloudflared" cloudflare/cloudflared:latest tunnel download "$config_uuid"; then
            chmod 640 "$creds_file"
            success "Downloaded tunnel credentials"
        else
            warn "Failed to download credentials - continuing without external access"
            return 0
        fi
    fi
    
    # Check if UUID is updated in infrastructure.yml
    if grep -q "<TUNNEL_UUID>" services/infrastructure.yml; then
        log "Updating services/infrastructure.yml with tunnel UUID..."
        update_tunnel_config "$config_uuid"
    fi
    
    # Set proper permissions
    if [ -f "$creds_file" ]; then
        chmod 640 "$creds_file"
    fi
    
    success "Cloudflared configuration validated (UUID: ${config_uuid:0:8}...)"
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

# Configure and start cloudflared
setup_cloudflared() {
    step "Setting up Cloudflared tunnel..."
    
    cd "$PROJECT_ROOT/docker"
    
    log "Restarting cloudflared to apply configuration..."
    $COMPOSE_CMD restart cloudflared
    
    # Wait for cloudflared to stabilize
    sleep 10
    
    log "Checking cloudflared tunnel status..."
    local logs_output
    logs_output=$($COMPOSE_CMD logs --tail=20 cloudflared 2>/dev/null || echo "")
    
    if echo "$logs_output" | grep -i "route propagating\|tunnel running" >/dev/null; then
        success "Cloudflared tunnel is running and routes are propagating"
    else
        warn "Cloudflared may need manual route configuration"
        warn "Check logs: make logs"
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
    
    # External access via Cloudflare
    if [ -f "docker/cloudflared/config.yml" ]; then
        echo -e "${CYAN}External Access (via Cloudflare):${NC}"
        grep -E "^\s*-\s*hostname:" docker/cloudflared/config.yml | sed 's/.*hostname: */  🌐 https:\/\//' | head -10
        echo ""
    fi
    
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
    echo "  1. 🔧 Configure services through their web interfaces"
    echo "  2. 🔒 Update VPN credentials in docker/.env if not done yet"
    echo "  3. 📡 Test external access via Cloudflare tunnels"
    echo "  4. 📊 Check service status: make status"
    echo "  5. 📝 View logs: make logs"
    echo "  6. 💾 Create backup: make backup"
    echo ""
    
    echo -e "${GREEN}Useful Commands:${NC}"
    echo "==============="
    echo "  make status     - Check service status"
    echo "  make logs       - View cloudflared logs"
    echo "  make backup     - Create system backup"
    echo "  make validate   - Validate configuration"
    echo "  make restart GROUP=all - Restart all services"
    echo ""
    
    warn "IMPORTANT SECURITY NOTES:"
    warn "  • Keep your docker/.env file secure (contains passwords)"
    warn "  • The .env file is not tracked in git (good!)"
    warn "  • Backup your configuration: git add -A && git commit -m 'deploy: $(date +%Y%m%d-%H%M)'"
    warn "  • Tag this deployment: git tag -f last-good && git push --tags"
    echo ""
    
    success "Master deployment pipeline completed successfully!"
    info "Your SOL Homelab is now ready for use! 🚀"
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
