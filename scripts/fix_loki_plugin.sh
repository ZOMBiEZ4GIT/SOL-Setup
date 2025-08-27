#!/usr/bin/env bash
set -euo pipefail

# Quick fix script for Loki logging plugin issue
# Run this if you encounter "loki plugin not found" errors

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

echo -e "${BLUE}SOL Homelab - Loki Plugin Fix${NC}"
echo "=================================="
echo ""

log "Checking for Loki logging plugin..."

# Check if plugin is already installed
if docker plugin ls | grep -q "loki"; then
    success "Loki logging plugin is already installed"
    log "The issue might be resolved. Try redeploying:"
    echo "  cd docker && docker compose up -d"
    exit 0
fi

log "Installing Loki logging driver plugin..."

# Install the plugin
if docker plugin install grafana/loki-docker-driver:latest --alias loki --grant-all-permissions; then
    success "Loki logging plugin installed successfully!"
    echo ""
    log "Now you can redeploy your services:"
    echo "  cd docker && docker compose down && docker compose up -d"
    echo ""
    log "Or remove any docker-compose.override.yml file if it exists:"
    echo "  rm -f docker/docker-compose.override.yml"
else
    error "Failed to install Loki logging plugin"
    echo ""
    warn "Alternative solutions:"
    echo "1. Deploy without Loki logging (will create override file):"
    echo "   make master-deploy"
    echo ""
    echo "2. Or manually disable Loki logging by creating docker-compose.override.yml:"
    echo "   See: https://docs.docker.com/compose/extends/"
    echo ""
    echo "3. Check Docker daemon logs for more details:"
    echo "   sudo journalctl -u docker.service"
fi
