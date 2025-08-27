#!/usr/bin/env bash
set -euo pipefail

# Password generation script for SOL Homelab
# Generates secure passwords and updates .env file

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_ROOT/docker/.env"
ENV_TEMPLATE="$PROJECT_ROOT/docker/env.template"

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

# Generate secure password
generate_password() {
    local length=${1:-32}
    openssl rand -base64 "$length" | tr -d "=+/" | cut -c1-"$length"
}

# Check if .env exists, create from template if not
setup_env_file() {
    if [ ! -f "$ENV_FILE" ]; then
        log "Creating .env file from template..."
        cp "$ENV_TEMPLATE" "$ENV_FILE"
        success "Created $ENV_FILE from template"
    else
        log "Using existing .env file: $ENV_FILE"
    fi
}

# Update password in .env file
update_password() {
    local key="$1"
    local password="$2"
    
    if grep -q "^${key}=" "$ENV_FILE"; then
        # Update existing password
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            sed -i '' "s/^${key}=.*/${key}=${password}/" "$ENV_FILE"
        else
            # Linux
            sed -i "s/^${key}=.*/${key}=${password}/" "$ENV_FILE"
        fi
        success "Updated $key in .env file"
    else
        # Add new password
        echo "${key}=${password}" >> "$ENV_FILE"
        success "Added $key to .env file"
    fi
}

# Generate and set all passwords
generate_all_passwords() {
    log "Generating secure passwords for all services..."
    
    # n8n password
    local n8n_password
    n8n_password=$(generate_password 24)
    update_password "N8N_PASSWORD" "$n8n_password"
    
    # Grafana admin password
    local grafana_password
    grafana_password=$(generate_password 24)
    update_password "GRAFANA_ADMIN_PASSWORD" "$grafana_password"
    
    # Generate backup encryption password if not exists
    local backup_password_file="$PROJECT_ROOT/.backup_password"
    if [ ! -f "$backup_password_file" ]; then
        local backup_password
        backup_password=$(generate_password 32)
        echo "$backup_password" > "$backup_password_file"
        chmod 600 "$backup_password_file"
        success "Generated backup encryption password"
    fi
    
    success "All passwords generated and updated in .env file"
}

# Display password summary
show_password_summary() {
    log "Password Summary:"
    echo "=================="
    
    if [ -f "$ENV_FILE" ]; then
        echo "n8n User: $(grep "^N8N_USER=" "$ENV_FILE" | cut -d'=' -f2)"
        echo "n8n Password: $(grep "^N8N_PASSWORD=" "$ENV_FILE" | cut -d'=' -f2)"
        echo "Grafana Admin Password: $(grep "^GRAFANA_ADMIN_PASSWORD=" "$ENV_FILE" | cut -d'=' -f2)"
        
        if [ -f "$PROJECT_ROOT/.backup_password" ]; then
            echo "Backup Encryption: Generated"
        fi
    fi
    
    echo ""
    warn "IMPORTANT: Keep these passwords secure and backup your .env file!"
    warn "Never commit .env file to version control!"
}

# Main function
main() {
    log "Starting password generation for SOL Homelab..."
    
    # Check if we're in the right directory
    if [ ! -f "$ENV_TEMPLATE" ]; then
        error "env.template not found. Run this script from the project root."
        exit 1
    fi
    
    # Setup environment file
    setup_env_file
    
    # Generate passwords
    generate_all_passwords
    
    # Show summary
    show_password_summary
    
    success "Password generation completed!"
    log "Next steps:"
    log "1. Review the generated passwords in $ENV_FILE"
    log "2. Update any service-specific configurations"
    log "3. Test the services with new credentials"
    log "4. Backup your .env file securely"
}

# Handle script interruption
trap 'error "Password generation interrupted"; exit 1' INT TERM

# Run main function
main "$@"
