#!/usr/bin/env bash
set -euo pipefail

# SOL Homelab Environment Setup Script
# Configure passwords, VPN credentials, and other environment variables

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
║                SOL HOMELAB ENVIRONMENT SETUP                 ║
║              Configure Passwords, VPN & Settings             ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    log "Environment Setup Script"
    log "This will configure secure passwords and environment variables"
    echo ""
}

# Check working directory
check_working_directory() {
    step "Checking working directory..."
    
    if [ ! -f "$PROJECT_ROOT/Makefile" ]; then
        error "Must be run from SOL-Setup repository root"
        exit 1
    fi
    
    success "Working directory: $PROJECT_ROOT"
}

# Generate secure password
generate_password() {
    local length=${1:-32}
    openssl rand -base64 "$length" | tr -d "=+/" | cut -c1-"$length"
}

# Setup secure passwords
setup_passwords() {
    step "Setting up secure passwords..."
    
    cd "$PROJECT_ROOT/docker"
    
    if [ ! -f ".env" ]; then
        error ".env file not found. Run 'make master-deploy' first."
        exit 1
    fi
    
    log "Generating secure passwords..."
    
    # Generate new passwords
    local n8n_password=$(generate_password 24)
    local grafana_password=$(generate_password 24)
    local backup_password=$(generate_password 32)
    
    # Update passwords in .env file
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s/N8N_PASSWORD=.*/N8N_PASSWORD=${n8n_password}/" .env
        sed -i '' "s/GRAFANA_ADMIN_PASSWORD=.*/GRAFANA_ADMIN_PASSWORD=${grafana_password}/" .env
    else
        # Linux
        sed -i "s/N8N_PASSWORD=.*/N8N_PASSWORD=${n8n_password}/" .env
        sed -i "s/GRAFANA_ADMIN_PASSWORD=.*/GRAFANA_ADMIN_PASSWORD=${grafana_password}/" .env
    fi
    
    # Generate backup encryption password
    echo "$backup_password" > "$PROJECT_ROOT/.backup_password"
    chmod 600 "$PROJECT_ROOT/.backup_password"
    
    success "Secure passwords generated and updated"
    
    # Show passwords
    echo ""
    info "Generated Credentials:"
    echo "======================"
    echo "  👤 n8n Admin:"
    echo "     User: admin"
    echo "     Password: $n8n_password"
    echo ""
    echo "  📊 Grafana Admin:"
    echo "     User: admin"
    echo "     Password: $grafana_password"
    echo ""
    echo "  🔐 Backup Encryption: Generated"
    echo ""
    warn "IMPORTANT: Save these credentials securely!"
}

# Setup VPN configuration
setup_vpn() {
    step "Setting up VPN configuration..."
    
    cd "$PROJECT_ROOT/docker"
    
    echo ""
    info "VPN Configuration"
    echo "================="
    echo ""
    echo "Choose your VPN provider and configuration:"
    echo "1. OpenVPN (ProtonVPN, NordVPN, etc.)"
    echo "2. WireGuard"
    echo "3. Skip VPN configuration"
    echo ""
    
    while true; do
        read -p "Enter your choice (1-3): " choice
        case $choice in
            1)
                setup_openvpn
                break
                ;;
            2)
                setup_wireguard
                break
                ;;
            3)
                warn "Skipping VPN configuration"
                warn "qBittorrent and other P2P services will not be protected"
                break
                ;;
            *)
                echo "Invalid choice. Please enter 1, 2, or 3."
                ;;
        esac
    done
}

# Setup OpenVPN
setup_openvpn() {
    info "Setting up OpenVPN configuration..."
    
    echo ""
    echo "Enter your OpenVPN credentials:"
    read -p "Username: " openvpn_user
    read -s -p "Password: " openvpn_password
    echo ""
    read -p "Protocol (udp/tcp) [udp]: " openvpn_protocol
    read -p "Server Countries [Australia]: " server_countries
    
    # Set defaults
    openvpn_protocol=${openvpn_protocol:-udp}
    server_countries=${server_countries:-Australia}
    
    # Update .env file
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s/OPENVPN_USER=.*/OPENVPN_USER=${openvpn_user}/" .env
        sed -i '' "s/OPENVPN_PASSWORD=.*/OPENVPN_PASSWORD=${openvpn_password}/" .env
        sed -i '' "s/OPENVPN_PROTOCOL=.*/OPENVPN_PROTOCOL=${openvpn_protocol}/" .env
        sed -i '' "s/SERVER_COUNTRIES=.*/SERVER_COUNTRIES=${server_countries}/" .env
    else
        # Linux
        sed -i "s/OPENVPN_USER=.*/OPENVPN_USER=${openvpn_user}/" .env
        sed -i "s/OPENVPN_PASSWORD=.*/OPENVPN_PASSWORD=${openvpn_password}/" .env
        sed -i "s/OPENVPN_PROTOCOL=.*/OPENVPN_PROTOCOL=${openvpn_protocol}/" .env
        sed -i "s/SERVER_COUNTRIES=.*/SERVER_COUNTRIES=${server_countries}/" .env
    fi
    
    success "OpenVPN configuration saved"
}

# Setup WireGuard
setup_wireguard() {
    info "Setting up WireGuard configuration..."
    
    echo ""
    echo "Enter your WireGuard configuration:"
    read -p "Private Key: " wg_private_key
    read -p "Addresses (e.g., 10.2.0.2/32): " wg_addresses
    read -p "Server Countries [Australia]: " server_countries
    
    server_countries=${server_countries:-Australia}
    
    # Comment out OpenVPN and set WireGuard
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s/^OPENVPN_USER=/#OPENVPN_USER=/" .env
        sed -i '' "s/^OPENVPN_PASSWORD=/#OPENVPN_PASSWORD=/" .env
        sed -i '' "s/^OPENVPN_PROTOCOL=/#OPENVPN_PROTOCOL=/" .env
        sed -i '' "s/^#.*WIREGUARD_PRIVATE_KEY=.*/WIREGUARD_PRIVATE_KEY=${wg_private_key}/" .env
        sed -i '' "s/^#.*WIREGUARD_ADDRESSES=.*/WIREGUARD_ADDRESSES=${wg_addresses}/" .env
        sed -i '' "s/SERVER_COUNTRIES=.*/SERVER_COUNTRIES=${server_countries}/" .env
    else
        # Linux
        sed -i "s/^OPENVPN_USER=/#OPENVPN_USER=/" .env
        sed -i "s/^OPENVPN_PASSWORD=/#OPENVPN_PASSWORD=/" .env
        sed -i "s/^OPENVPN_PROTOCOL=/#OPENVPN_PROTOCOL=/" .env
        sed -i "s/^#.*WIREGUARD_PRIVATE_KEY=.*/WIREGUARD_PRIVATE_KEY=${wg_private_key}/" .env
        sed -i "s/^#.*WIREGUARD_ADDRESSES=.*/WIREGUARD_ADDRESSES=${wg_addresses}/" .env
        sed -i "s/SERVER_COUNTRIES=.*/SERVER_COUNTRIES=${server_countries}/" .env
    fi
    
    success "WireGuard configuration saved"
}

# Setup timezone and user settings
setup_system_settings() {
    step "Setting up system settings..."
    
    cd "$PROJECT_ROOT/docker"
    
    echo ""
    info "System Settings"
    echo "==============="
    echo ""
    
    # Get current user ID
    local current_uid=$(id -u)
    local current_gid=$(id -g)
    
    read -p "Timezone [Australia/Melbourne]: " timezone
    read -p "User ID [$current_uid]: " puid
    read -p "Group ID [$current_gid]: " pgid
    
    # Set defaults
    timezone=${timezone:-Australia/Melbourne}
    puid=${puid:-$current_uid}
    pgid=${pgid:-$current_gid}
    
    # Update .env file
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s/TZ=.*/TZ=${timezone}/" .env
        sed -i '' "s/PUID=.*/PUID=${puid}/" .env
        sed -i '' "s/PGID=.*/PGID=${pgid}/" .env
    else
        # Linux
        sed -i "s/TZ=.*/TZ=${timezone}/" .env
        sed -i "s/PUID=.*/PUID=${puid}/" .env
        sed -i "s/PGID=.*/PGID=${pgid}/" .env
    fi
    
    success "System settings configured"
}

# Restart services to apply new configuration
restart_services() {
    step "Restarting services to apply new configuration..."
    
    cd "$PROJECT_ROOT/docker"
    
    info "This will restart all services with the new configuration..."
    read -p "Continue? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        warn "Skipping service restart"
        warn "You'll need to restart services manually: cd docker && docker compose restart"
        return 0
    fi
    
    log "Restarting services..."
    if docker compose restart; then
        success "Services restarted successfully"
    else
        warn "Some services failed to restart"
        info "Check logs: make logs"
    fi
}

# Show configuration summary
show_summary() {
    step "Environment Configuration Complete!"
    
    echo -e "${GREEN}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                 🎉 ENVIRONMENT SETUP COMPLETE! 🎉           ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    success "Environment configuration has been completed successfully!"
    
    echo ""
    info "What's been configured:"
    echo "✅ Secure passwords for all services"
    echo "✅ VPN configuration (if selected)"
    echo "✅ Timezone and user settings"
    echo "✅ Services restarted with new configuration"
    
    echo ""
    info "Next steps:"
    echo "1. 🌐 Setup external access: make setup-tunnel"
    echo "2. 🔧 Configure individual services through their web interfaces"
    echo "3. 📊 Check service status: make status"
    echo "4. 💾 Create backup: make backup"
    
    echo ""
    warn "IMPORTANT:"
    warn "• Keep your docker/.env file secure (contains passwords)"
    warn "• Backup your configuration regularly"
    warn "• Test VPN connection if configured"
}

# Main function
main() {
    show_banner
    check_working_directory
    setup_passwords
    setup_vpn
    setup_system_settings
    restart_services
    show_summary
    
    success "🎉 Environment setup completed successfully! 🎉"
}

# Handle script interruption
cleanup_on_exit() {
    error "Setup interrupted"
    exit 1
}

trap cleanup_on_exit INT TERM

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --passwords-only)
            setup_passwords_only() {
                show_banner
                check_working_directory
                setup_passwords
                success "Passwords updated successfully!"
            }
            setup_passwords_only
            exit 0
            ;;
        --help|-h)
            echo "SOL Homelab Environment Setup Script"
            echo ""
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --passwords-only  Only update passwords, skip other configuration"
            echo "  --help, -h        Show this help message"
            echo ""
            echo "This script configures passwords, VPN credentials, and system settings"
            echo "for your SOL Homelab deployment."
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            error "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Run the main setup
main "$@"
