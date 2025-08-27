#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../docker"

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

echo ">> docker compose lint/merge"
if docker compose config >/dev/null; then
    success "Docker Compose configuration is valid"
else
    error "Docker Compose configuration has errors"
    exit 1
fi

echo ">> checking for port conflicts"
# Check for duplicate port mappings
port_conflicts=$(docker compose config | grep -E "ports:" -A 1 | grep -E "[0-9]+:[0-9]+" | sed 's/.*"\([0-9]*\):.*/\1/' | sort | uniq -d)

if [ -n "$port_conflicts" ]; then
    error "Port conflicts detected: $port_conflicts"
    exit 1
else
    success "No port conflicts detected"
fi

echo ">> checking environment variables"
# Check if .env file exists
if [ ! -f ".env" ]; then
    warn ".env file not found. Run 'make setup-passwords' to create it."
else
    # Check for placeholder passwords
    if grep -q "change_me\|<generate_secure_password_here>" .env; then
        warn "Some passwords still need to be set. Run 'make setup-passwords' to generate secure passwords."
    else
        success "Environment variables configured"
    fi
fi

echo ">> quick local port checks"
ports=(32400 8989 7878 5678 8080 9000 7575 9696 6767 5055 8181 61208 3001 9999 3000 8081)
for p in "${ports[@]}"; do
  if (curl -fsS "http://127.0.0.1:$p" -m 1 >/dev/null 2>&1); then
    echo -e "${GREEN}port $p OK${NC}"
  else
    echo -e "${YELLOW}port $p n/a${NC}"
  fi
done

echo ">> security checks"
# Check for security_opt on all services
services_without_security=$(docker compose config | grep -A 20 "services:" | grep -v "security_opt" | grep -E "^  [a-zA-Z]" | grep -v "gluetun" | sed 's/^  //' | sed 's/:$//' | tr '\n' ' ')

if [ -n "$services_without_security" ]; then
    warn "Services without security_opt: $services_without_security"
else
    success "All services have security constraints configured"
fi

success "Validation completed successfully!"
