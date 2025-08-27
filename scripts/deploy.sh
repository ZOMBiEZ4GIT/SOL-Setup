#!/usr/bin/env bash
set -euo pipefail

# SOL Homelab Deployment Script
# Robust deployment with fail-fast error handling and proper directory management

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check if we're in the right directory and navigate to docker/
check_working_directory() {
    if [ ! -f "Makefile" ] && [ ! -f "../Makefile" ]; then
        error "Run this script from the SOL-Setup repository root"
        error "Expected: cd ~/SOL-Setup && make deploy"
        exit 1
    fi
    
    # Navigate to docker directory
    if [ -f "Makefile" ]; then
        cd docker
    elif [ -f "../Makefile" ]; then
        cd ../docker
    fi
    
    if [ ! -f "docker-compose.yml" ]; then
        error "docker-compose.yml not found in docker/ directory"
        exit 1
    fi
    
    success "Working directory: $(pwd)"
}

# Check environment file
check_environment() {
    if [ ! -f ".env" ]; then
        error "Missing docker/.env file"
        error "Run: cp docker/env.template docker/.env && nano docker/.env"
        exit 1
    fi
    
    success "Found docker/.env file"
}

# Check Docker availability
check_docker() {
    if ! command -v docker &> /dev/null; then
        error "Docker not found. Please install Docker first."
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        error "Docker daemon not running. Please start Docker first."
        exit 1
    fi
    
    # Check docker compose command
    if docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
    elif docker-compose version &> /dev/null; then
        COMPOSE_CMD="docker-compose"
    else
        error "Neither 'docker compose' nor 'docker-compose' available"
        exit 1
    fi
    
    success "Docker is available (using: $COMPOSE_CMD)"
}

# Pull latest images
pull_images() {
    log "Pulling latest images..."
    
    if $COMPOSE_CMD pull; then
        success "Images pulled successfully"
    else
        error "Failed to pull images"
        exit 1
    fi
}

# Deploy services
deploy_services() {
    log "Starting services..."
    
    if $COMPOSE_CMD up -d; then
        success "Services started successfully"
    else
        error "Failed to start services"
        
        # Try to provide helpful error information
        log "Checking for common issues..."
        
        # Check if AdGuard port 53 conflict
        if $COMPOSE_CMD logs adguardhome 2>/dev/null | grep -i "bind.*:53.*address already in use" >/dev/null 2>&1; then
            error "AdGuard Home cannot bind to port 53 (DNS conflict)"
            error "Fix with:"
            error "  sudo sed -i 's/^#\\?DNSStubListener=.*/DNSStubListener=no/' /etc/systemd/resolved.conf"
            error "  sudo systemctl restart systemd-resolved"
            error "  $COMPOSE_CMD restart adguardhome"
        fi
        
        exit 1
    fi
}

# Restart cloudflared and check routes
restart_cloudflared() {
    log "Restarting cloudflared to reload ingress configuration..."
    
    if $COMPOSE_CMD restart cloudflared; then
        success "Cloudflared restarted successfully"
    else
        error "Failed to restart cloudflared"
        exit 1
    fi
    
    # Wait for cloudflared to start
    sleep 5
    
    log "Checking cloudflared tunnel status..."
    local logs_output
    logs_output=$($COMPOSE_CMD logs --tail=50 cloudflared 2>/dev/null || echo "")
    
    # Check for route propagation
    if echo "$logs_output" | grep -i "route propagating" >/dev/null; then
        success "Routes are propagating successfully"
        echo "$logs_output" | grep -i "route propagating" | tail -3
    else
        warn "No 'route propagating' messages found in cloudflared logs"
        warn "If services are not accessible externally, register DNS routes:"
        warn "  cd docker/cloudflared"
        warn "  # For each hostname in config.yml:"
        warn "  docker run --rm -v \$(pwd):/root/.cloudflared cloudflare/cloudflared:latest \\"
        warn "    tunnel route dns <TUNNEL_UUID> <hostname>"
        
        # Show recent logs for debugging
        echo -e "\n${YELLOW}Recent cloudflared logs:${NC}"
        echo "$logs_output" | tail -10
    fi
}

# Health check
health_check() {
    log "Performing health check..."
    
    # Wait for services to stabilize
    sleep 10
    
    # Check running containers
    local running_containers total_services
    running_containers=$($COMPOSE_CMD ps --services --filter "status=running" | wc -l)
    total_services=$($COMPOSE_CMD ps --services | wc -l)
    
    if [ "$running_containers" -eq "$total_services" ]; then
        success "All $total_services services are running"
    else
        warn "Only $running_containers of $total_services services are running"
        
        # Show status of non-running services
        log "Service status:"
        $COMPOSE_CMD ps
        
        # Check for common issues
        log "Checking for common issues..."
        
        # Check for failed containers and show their logs
        local failed_services
        failed_services=$($COMPOSE_CMD ps --services --filter "status=exited" | head -3)
        
        if [ -n "$failed_services" ]; then
            while IFS= read -r service; do
                if [ -n "$service" ]; then
                    warn "Service '$service' has exited. Recent logs:"
                    $COMPOSE_CMD logs --tail=10 "$service" | head -20
                fi
            done <<< "$failed_services"
        fi
    fi
}

# Show deployment summary
show_deployment_summary() {
    success "Deployment completed!"
    
    log "Next steps:"
    log "1. Check service status: make logs"
    log "2. Validate deployment: make validate"
    log "3. Access services via:"
    
    # Extract hostnames from cloudflared config if available
    if [ -f "cloudflared/config.yml" ]; then
        echo -e "${GREEN}   External URLs:${NC}"
        grep -E "^\s*-\s*hostname:" cloudflared/config.yml | sed 's/.*hostname: */     https:\/\//' | head -5
        if [ "$(grep -c -E "^\s*-\s*hostname:" cloudflared/config.yml)" -gt 5 ]; then
            echo "     ... and more (see cloudflared/config.yml)"
        fi
    fi
    
    echo -e "${GREEN}   Local URLs:${NC}"
    echo "     http://localhost:7575 (Homarr Dashboard)"
    echo "     http://localhost:9000 (Portainer)"
    echo "     http://localhost:32400 (Plex)"
    echo ""
    
    log "Create a backup point:"
    log "  git add -A && git commit -m 'deploy: $(date +%Y%m%d-%H%M)'"
    log "  git tag -f last-good && git push --tags"
}

# Main deployment function
main() {
    log "Starting SOL Homelab deployment..."
    
    # Pre-flight checks
    check_working_directory
    check_environment
    check_docker
    
    # Deploy
    pull_images
    deploy_services
    restart_cloudflared
    
    # Post-deployment checks
    health_check
    show_deployment_summary
    
    success "Deployment pipeline completed successfully!"
}

# Handle script interruption
trap 'error "Deployment interrupted"; exit 1' INT TERM

# Run main function
main "$@"