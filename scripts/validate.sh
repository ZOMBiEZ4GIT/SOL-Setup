#!/usr/bin/env bash
set -euo pipefail

# SOL Homelab Validation Script
# Comprehensive pre-deployment validation with dependency checks, env validation, and cloudflared checks

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
        error "Expected structure: SOL-Setup/scripts/validate.sh"
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

# Check for required dependencies
check_dependencies() {
    log "Checking dependencies..."
    local missing_deps=()
    
    for cmd in docker curl sed awk; do
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
        error "Install missing dependencies and try again"
        exit 1
    fi
    
    success "All dependencies available"
}

# Check .env file and validate required variables
check_environment_file() {
    log "Checking environment configuration..."
    
    if [ ! -f ".env" ]; then
        error "Missing docker/.env file"
        error "Run: cp docker/env.template docker/.env && nano docker/.env"
        exit 1
    fi
    
    success "Found docker/.env file"
    
    # Source the .env file for validation
    set -a  # automatically export all variables
    source .env
    set +a
    
    # Check required variables
    local missing_vars=()
    for var in PUID PGID TZ; do
        if [ -z "${!var:-}" ]; then
            missing_vars+=("$var")
        fi
    done
    
    # Check VPN configuration - require either OpenVPN or WireGuard
    local openvpn_configured=true
    local wireguard_configured=true
    
    for var in OPENVPN_USER OPENVPN_PASSWORD OPENVPN_PROTOCOL SERVER_COUNTRIES; do
        if [ -z "${!var:-}" ] || [ "${!var}" = "<your_proton_openvpn_user_or_appuser>" ] || [ "${!var}" = "<your_proton_openvpn_password>" ]; then
            openvpn_configured=false
            break
        fi
    done
    
    for var in WIREGUARD_PRIVATE_KEY WIREGUARD_ADDRESSES; do
        if [ -z "${!var:-}" ]; then
            wireguard_configured=false
            break
        fi
    done
    
    if [ "$openvpn_configured" = false ] && [ "$wireguard_configured" = false ]; then
        error "VPN configuration incomplete. Configure either OpenVPN or WireGuard in .env"
        exit 1
    fi
    
    if [ ${#missing_vars[@]} -ne 0 ]; then
        error "Missing required environment variables: ${missing_vars[*]}"
        exit 1
    fi
    
    success "Environment variables configured properly"
    
    if [ "$openvpn_configured" = true ]; then
        success "OpenVPN configuration found"
    else
        success "WireGuard configuration found"
    fi
}

# Validate Docker Compose configuration
validate_compose_config() {
    log "Validating Docker Compose configuration..."
    
    if ! docker compose config >/dev/null 2>&1; then
        error "Docker Compose configuration has errors:"
        docker compose config
        exit 1
    fi
    
    success "Docker Compose configuration is valid"
}

# Check for port conflicts
check_port_conflicts() {
    log "Checking for port conflicts..."
    
    # Get all published ports from compose config
    local ports
    ports=$(docker compose config | grep -E "^\s*-\s*[\"']?[0-9]+:[0-9]+" | sed -E 's/.*"?([0-9]+):[0-9]+.*/\1/' | sort -n)
    
    local conflicts
    conflicts=$(echo "$ports" | uniq -d)
    
    if [ -n "$conflicts" ]; then
        error "Port conflicts detected: $(echo $conflicts | tr '\n' ' ')"
        exit 1
    fi
    
    success "No port conflicts detected"
}

# Validate Cloudflared configuration
check_cloudflared_config() {
    log "Checking Cloudflared configuration..."
    
    if [ ! -f "cloudflared/config.yml" ]; then
        error "cloudflared/config.yml not found"
        exit 1
    fi
    
    # Extract UUID from config.yml
    local config_uuid
    config_uuid=$(grep "^tunnel:" cloudflared/config.yml | sed 's/tunnel: *//' | tr -d ' ')
    
    if [ "$config_uuid" = "<TUNNEL_UUID>" ] || [ -z "$config_uuid" ]; then
        error "Tunnel UUID not configured in cloudflared/config.yml"
        error "Update tunnel UUID in both docker-compose.yml and cloudflared/config.yml"
        error "Get UUID with: docker run --rm cloudflare/cloudflared:latest tunnel list"
        exit 1
    fi
    
    # Check if credentials file exists
    local creds_file="cloudflared/${config_uuid}.json"
    if [ ! -f "$creds_file" ]; then
        error "Tunnel credentials file not found: $creds_file"
        error "Create tunnel and download credentials:"
        error "  docker run --rm -v \$(pwd)/cloudflared:/root/.cloudflared cloudflare/cloudflared:latest tunnel login"
        error "  docker run --rm -v \$(pwd)/cloudflared:/root/.cloudflared cloudflare/cloudflared:latest tunnel create my-tunnel"
        error "  # OR download existing: docker run --rm -v \$(pwd)/cloudflared:/root/.cloudflared cloudflare/cloudflared:latest tunnel download $config_uuid"
        exit 1
    fi
    
    # Check file permissions (should be readable by uid 65532)
    if [ ! -r "$creds_file" ]; then
        warn "Tunnel credentials may not be readable by cloudflared container"
        warn "Fix with: sudo chown 65532:65532 cloudflared/*.json && sudo chmod 640 cloudflared/*.json"
    fi
    
    # Check if UUID matches in docker-compose.yml
    if ! grep -q "$config_uuid" docker-compose.yml && ! grep -q "$config_uuid" services/infrastructure.yml; then
        error "Tunnel UUID mismatch between config.yml and docker-compose.yml/services/infrastructure.yml"
        error "Update the command in cloudflared service to use: tunnel --no-autoupdate run $config_uuid"
        exit 1
    fi
    
    success "Cloudflared configuration validated (UUID: ${config_uuid:0:8}...)"
}

# Test local port connectivity
test_local_ports() {
    log "Testing local port connectivity..."
    
    local ports=(32400 8989 7878 5678 8080 9000 7575 9696 6767 5055 8181 61208 3001 9999 3000)
    local timeout=1
    
    for port in "${ports[@]}"; do
        if timeout "$timeout" bash -c "</dev/tcp/127.0.0.1/$port" 2>/dev/null; then
            echo -e "${GREEN}port $port OK${NC}"
        else
            echo -e "${YELLOW}port $port n/a${NC}"
        fi
    done
}

# Security validation
check_security_configuration() {
    log "Checking security configuration..."
    
    # Check that services have security_opt (except those that need privileges)
    local compose_config
    compose_config=$(docker compose config)
    
    # Services that should have security_opt
    local services_needing_security
    services_needing_security=$(echo "$compose_config" | grep -E "^  [a-zA-Z]" | grep -v "gluetun" | sed 's/^  //' | sed 's/:$//')
    
    local insecure_services=()
    while IFS= read -r service; do
        if [ -n "$service" ]; then
            # Check if service has security_opt in the config
            if ! echo "$compose_config" | sed -n "/^  $service:/,/^  [a-zA-Z]/p" | grep -q "security_opt"; then
                insecure_services+=("$service")
            fi
        fi
    done <<< "$services_needing_security"
    
    if [ ${#insecure_services[@]} -gt 0 ]; then
        warn "Services without security_opt: ${insecure_services[*]}"
        warn "Consider adding 'security_opt: [\"no-new-privileges:true\"]' to these services"
    else
        success "Security constraints properly configured"
    fi
}

# Main validation function
main() {
    log "Starting SOL Homelab validation..."
    
    check_working_directory
    check_dependencies
    check_environment_file
    validate_compose_config
    check_port_conflicts
    check_cloudflared_config
    test_local_ports
    check_security_configuration
    
    success "Validation completed successfully!"
    log "System is ready for deployment"
    
    exit 0
}

# Handle script interruption
trap 'error "Validation interrupted"; exit 1' INT TERM

# Run main function
main "$@"