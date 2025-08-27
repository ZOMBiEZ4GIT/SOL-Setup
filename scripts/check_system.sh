#!/usr/bin/env bash
set -euo pipefail

# SOL Homelab System Check Script
# Quick system verification before deployment

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[CHECK]${NC} $1"
}

success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

error() {
    echo -e "${RED}[✗]${NC} $1"
}

echo "SOL Homelab - System Check"
echo "=========================="
echo ""

# Check OS
log "Checking operating system..."
if [ -f /etc/os-release ]; then
    . /etc/os-release
    success "OS: $PRETTY_NAME"
    if [[ "$ID" == "ubuntu" ]]; then
        success "Ubuntu detected - fully supported"
    else
        warn "Non-Ubuntu system - should work but not fully tested"
    fi
else
    warn "Cannot determine OS version"
fi

# Check architecture
log "Checking system architecture..."
ARCH=$(uname -m)
success "Architecture: $ARCH"
if [[ "$ARCH" == "x86_64" ]]; then
    success "x86_64 architecture - fully supported"
elif [[ "$ARCH" == "aarch64" ]]; then
    success "ARM64 architecture - supported"
else
    warn "Unusual architecture - some containers may not be available"
fi

# Check memory
log "Checking available memory..."
MEM_GB=$(free -g | awk '/^Mem:/{print $2}')
if [ "$MEM_GB" -ge 8 ]; then
    success "Memory: ${MEM_GB}GB - excellent"
elif [ "$MEM_GB" -ge 4 ]; then
    success "Memory: ${MEM_GB}GB - sufficient"
else
    warn "Memory: ${MEM_GB}GB - may be insufficient for all services"
fi

# Check disk space
log "Checking disk space..."
DISK_GB=$(df -BG . | awk 'NR==2{print $4}' | sed 's/G//')
if [ "$DISK_GB" -ge 100 ]; then
    success "Free space: ${DISK_GB}GB - excellent"
elif [ "$DISK_GB" -ge 50 ]; then
    success "Free space: ${DISK_GB}GB - sufficient"
else
    warn "Free space: ${DISK_GB}GB - may be insufficient for media storage"
fi

# Check internet connectivity
log "Checking internet connectivity..."
if ping -c 1 google.com &> /dev/null; then
    success "Internet connectivity - working"
else
    error "No internet connectivity - required for downloading images"
fi

# Check sudo access
log "Checking sudo access..."
if sudo -n true 2>/dev/null; then
    success "Sudo access - available (passwordless)"
elif sudo -v 2>/dev/null; then
    success "Sudo access - available (with password)"
else
    error "No sudo access - required for installation"
fi

# Check if ports are available
log "Checking common ports..."
PORTS_TO_CHECK="80 443 3000 5678 7575 8080 8989 7878 9000 9090 9696"
PORTS_IN_USE=""

for port in $PORTS_TO_CHECK; do
    if netstat -tuln 2>/dev/null | grep -q ":${port} " || ss -tuln 2>/dev/null | grep -q ":${port} "; then
        PORTS_IN_USE="$PORTS_IN_USE $port"
    fi
done

if [ -z "$PORTS_IN_USE" ]; then
    success "All common ports available"
else
    warn "Ports in use: $PORTS_IN_USE"
    warn "These may conflict with SOL services"
fi

# Check Docker
log "Checking Docker..."
if command -v docker &> /dev/null; then
    if docker info &> /dev/null 2>&1; then
        DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | tr -d ',')
        success "Docker installed and running - version $DOCKER_VERSION"
    else
        warn "Docker installed but not running"
    fi
else
    warn "Docker not installed - will be auto-installed during deployment"
fi

# Check Git
log "Checking Git..."
if command -v git &> /dev/null; then
    GIT_VERSION=$(git --version | cut -d' ' -f3)
    success "Git installed - version $GIT_VERSION"
else
    error "Git not installed - required for deployment"
    echo "Install with: sudo apt update && sudo apt install -y git"
fi

echo ""
echo "System check complete!"
echo ""
echo "Next steps:"
echo "1. If any errors above, fix them first"
echo "2. Run: make master-deploy"
echo "3. Follow the setup prompts"
