#!/usr/bin/env bash
set -euo pipefail

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

# Check if we're in the right directory
check_environment() {
    if [ ! -f "docker-compose.yml" ]; then
        error "docker-compose.yml not found. Run this script from the project root."
        exit 1
    fi
    
    if [ ! -f ".env" ]; then
        warn ".env file not found. Run 'make setup-passwords' first."
        warn "Continuing with deployment..."
    fi
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
}

# Deploy services
deploy_services() {
    cd docker
    
    log "Pulling latest images..."
    if docker compose pull; then
        success "Images pulled successfully"
    else
        error "Failed to pull images"
        exit 1
    fi
    
    log "Starting services..."
    if docker compose up -d; then
        success "Services started successfully"
    else
        error "Failed to start services"
        exit 1
    fi
    
    log "Restarting cloudflared to reload ingress..."
    if docker compose restart cloudflared; then
        success "Cloudflared restarted successfully"
    else
        error "Failed to restart cloudflared"
        exit 1
    fi
    
    log "Checking cloudflared routes..."
    docker compose logs -n 120 cloudflared | grep -E "(route propagating|error|failed)" || true
}

# Health check
health_check() {
    log "Performing health check..."
    
    # Wait for services to start
    sleep 10
    
    # Check if containers are running
    local running_containers=$(docker compose ps --services --filter "status=running" | wc -l)
    local total_services=$(docker compose ps --services | wc -l)
    
    if [ "$running_containers" -eq "$total_services" ]; then
        success "All services are running"
    else
        warn "Some services may not be running properly"
        docker compose ps
    fi
}

# Main deployment process
main() {
    log "Starting SOL Homelab deployment..."
    
    # Pre-flight checks
    check_environment
    check_docker
    
    # Deploy
    deploy_services
    
    # Health check
    health_check
    
    success "Deployment completed successfully!"
    log "Next steps:"
    log "1. Check service status: make logs"
    log "2. Validate configuration: make validate"
    log "3. Access services via Cloudflare Tunnel"
}

# Handle script interruption
trap 'error "Deployment interrupted"; exit 1' INT TERM

# Run main function
main "$@"
