#!/usr/bin/env bash
set -euo pipefail

# SOL Homelab Cloudflare Tunnel Setup Script
# Interactive setup for external access via Cloudflare tunnels

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
║              SOL HOMELAB CLOUDFLARE TUNNEL SETUP             ║
║                   External Access Configuration              ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    log "Cloudflare Tunnel Setup Script"
    log "This will configure external access to your homelab services"
    echo ""
}

# Check if we're in the right directory
check_working_directory() {
    step "Checking working directory..."
    
    if [ ! -f "$PROJECT_ROOT/Makefile" ]; then
        error "Must be run from SOL-Setup repository root"
        error "Expected: cd ~/SOL-Setup && bash scripts/setup_tunnel.sh"
        exit 1
    fi
    
    success "Working directory: $PROJECT_ROOT"
}

# Check dependencies
check_dependencies() {
    step "Checking dependencies..."
    
    if ! command -v docker &> /dev/null; then
        error "Docker not found. Please install Docker first."
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        error "Docker daemon not running. Please start Docker first."
        exit 1
    fi
    
    success "Dependencies available"
}

# Interactive Cloudflare tunnel setup
setup_cloudflare_tunnel() {
    step "Starting Cloudflare tunnel setup..."
    
    cd "$PROJECT_ROOT/docker"
    
    echo ""
    info "🔧 CLOUDFLARE TUNNEL CONFIGURATION"
    echo "==================================="
    echo ""
    echo "This script will:"
    echo "1. Login to your Cloudflare account"
    echo "2. Create or use an existing tunnel"
    echo "3. Configure tunnel UUID in config files"
    echo "4. Download tunnel credentials"
    echo "5. Register DNS routes (optional)"
    echo ""
    
    read -p "Continue with Cloudflare tunnel setup? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Setup cancelled. Your homelab will remain local-only."
        exit 0
    fi
    
    # Step 1: Login
    echo ""
    info "Step 1: Login to Cloudflare"
    echo "This will open a browser window for authentication..."
    read -p "Press Enter to continue..."
    
    if ! docker run --rm -v "$(pwd)/cloudflared:/root/.cloudflared" cloudflare/cloudflared:latest tunnel login; then
        error "Failed to login to Cloudflare"
        exit 1
    fi
    
    success "Successfully logged into Cloudflare"
    
    # Step 2: List existing tunnels or create new one
    echo ""
    info "Step 2: Choose tunnel"
    echo "Checking for existing tunnels..."
    
    local tunnel_list
    local list_exit_code
    local tunnel_uuid
    
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
    
    # Step 5: Register DNS routes
    setup_dns_routes "$tunnel_uuid"
    
    # Final validation
    validate_tunnel_config
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
        exit 1
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
        success "Updated cloudflared/config.yml"
    fi
    
    # Update services/infrastructure.yml
    if [ -f "services/infrastructure.yml" ]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s/<TUNNEL_UUID>/$uuid/g" services/infrastructure.yml
        else
            sed -i "s/<TUNNEL_UUID>/$uuid/g" services/infrastructure.yml
        fi
        success "Updated services/infrastructure.yml"
    fi
}

# Setup DNS routes
setup_dns_routes() {
    local tunnel_uuid="$1"
    
    echo ""
    info "Step 5: DNS Route Registration"
    echo "=============================="
    echo ""
    echo "To make your services accessible externally, we need to register DNS routes."
    echo "This maps your domain names (like plex.rolandgeorge.me) to your tunnel."
    echo ""
    
    read -p "Do you want to register DNS routes now? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        warn "Skipping DNS route registration"
        warn "You'll need to register routes manually later for external access"
        show_manual_dns_commands "$tunnel_uuid"
        return 0
    fi
    
    log "Registering DNS routes for all services..."
    
    # Extract hostnames from config.yml
    local hostnames=()
    while IFS= read -r line; do
        if [[ $line =~ hostname:\ (.+) ]]; then
            hostnames+=("${BASH_REMATCH[1]}")
        fi
    done < cloudflared/config.yml
    
    local success_count=0
    local total_count=${#hostnames[@]}
    
    for hostname in "${hostnames[@]}"; do
        log "Registering route for $hostname..."
        if docker run --rm -v "$(pwd)/cloudflared:/root/.cloudflared" cloudflare/cloudflared:latest tunnel route dns "$tunnel_uuid" "$hostname" 2>/dev/null; then
            success "✓ $hostname"
            ((success_count++))
        else
            warn "✗ Failed to register $hostname (may already exist)"
        fi
    done
    
    echo ""
    if [ $success_count -eq $total_count ]; then
        success "All DNS routes registered successfully!"
    else
        warn "Registered $success_count of $total_count routes"
        info "Some routes may have been already registered"
    fi
}

# Show manual DNS commands
show_manual_dns_commands() {
    local tunnel_uuid="$1"
    
    echo ""
    info "Manual DNS Route Registration Commands:"
    echo "======================================="
    echo ""
    echo "Run these commands later to register DNS routes:"
    echo ""
    
    # Extract hostnames from config.yml
    while IFS= read -r line; do
        if [[ $line =~ hostname:\ (.+) ]]; then
            echo "docker run --rm -v \$(pwd)/cloudflared:/root/.cloudflared cloudflare/cloudflared:latest tunnel route dns $tunnel_uuid ${BASH_REMATCH[1]}"
        fi
    done < cloudflared/config.yml
    echo ""
}

# Validate tunnel configuration
validate_tunnel_config() {
    step "Validating tunnel configuration..."
    
    # Check that UUID is no longer placeholder
    if grep -q "<TUNNEL_UUID>" cloudflared/config.yml; then
        error "Configuration still contains placeholder UUIDs"
        exit 1
    fi
    
    # Extract UUID from config
    local config_uuid
    config_uuid=$(grep "^tunnel:" cloudflared/config.yml | sed 's/tunnel: *//' | tr -d ' ')
    
    # Check credentials file exists
    if [ ! -f "cloudflared/${config_uuid}.json" ]; then
        error "Credentials file not found: cloudflared/${config_uuid}.json"
        exit 1
    fi
    
    success "Tunnel configuration validated successfully!"
}

# Test tunnel connectivity
test_tunnel() {
    step "Testing tunnel connectivity..."
    
    echo ""
    info "Starting tunnel test..."
    echo "This will start cloudflared briefly to test connectivity"
    
    cd "$PROJECT_ROOT/docker"
    
    # Start tunnel in background for testing
    local tunnel_uuid
    tunnel_uuid=$(grep "^tunnel:" cloudflared/config.yml | sed 's/tunnel: *//' | tr -d ' ')
    
    log "Starting tunnel test (this may take 30 seconds)..."
    
    # Use timeout to limit test duration
    if timeout 30s docker run --rm -v "$(pwd)/cloudflared:/root/.cloudflared" cloudflare/cloudflared:latest tunnel --no-autoupdate run "$tunnel_uuid" &>/dev/null; then
        success "Tunnel connectivity test passed!"
    else
        warn "Tunnel test timed out or failed (this may be normal)"
        info "Your tunnel should still work when deployed with docker-compose"
    fi
}

# Show final summary
show_setup_summary() {
    step "Setup Complete!"
    
    echo -e "${GREEN}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                 🎉 TUNNEL SETUP COMPLETE! 🎉                ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    success "Cloudflare tunnel has been configured successfully!"
    
    echo ""
    info "What's been configured:"
    echo "✅ Cloudflare tunnel created/selected"
    echo "✅ Configuration files updated with tunnel UUID"
    echo "✅ Tunnel credentials downloaded"
    echo "✅ DNS routes registered (if selected)"
    
    echo ""
    info "Next steps:"
    echo "1. 🚀 Deploy/restart your homelab: make deploy"
    echo "2. 🌐 Test external access via your domain names"
    echo "3. 🔧 Configure services through their web interfaces"
    
    echo ""
    info "Your services will be accessible at:"
    # Extract hostnames from config.yml
    while IFS= read -r line; do
        if [[ $line =~ hostname:\ (.+) ]]; then
            echo "  🌐 https://${BASH_REMATCH[1]}"
        fi
    done < docker/cloudflared/config.yml | head -5
    echo "  ... and more!"
    
    echo ""
    warn "Important notes:"
    warn "• DNS propagation may take a few minutes"
    warn "• Ensure your homelab services are running: make status"
    warn "• Check cloudflared logs if needed: make logs"
}

# Main function
main() {
    show_banner
    check_working_directory
    check_dependencies
    setup_cloudflare_tunnel
    test_tunnel
    show_setup_summary
    
    success "🎉 Cloudflare tunnel setup completed successfully! 🎉"
}

# Handle script interruption
cleanup_on_exit() {
    error "Setup interrupted"
    exit 1
}

trap cleanup_on_exit INT TERM

# Parse command line arguments
SKIP_DNS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-dns)
            SKIP_DNS=true
            shift
            ;;
        --help|-h)
            echo "SOL Homelab Cloudflare Tunnel Setup Script"
            echo ""
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --skip-dns       Skip DNS route registration"
            echo "  --help, -h       Show this help message"
            echo ""
            echo "This script configures Cloudflare tunnels for external access"
            echo "to your homelab services."
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            error "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Override DNS setup if requested
if [ "$SKIP_DNS" = true ]; then
    setup_dns_routes() {
        local tunnel_uuid="$1"
        warn "Skipping DNS route registration (--skip-dns flag provided)"
        show_manual_dns_commands "$tunnel_uuid"
    }
fi

# Run the main setup
main "$@"
