#!/usr/bin/env bash
set -euo pipefail

# SOL Homelab Route Testing Script
# Tests local origins defined in cloudflared ingress configuration

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

# Check working directory and navigate to docker/
check_working_directory() {
    if [ ! -f "Makefile" ] && [ ! -f "../Makefile" ]; then
        error "Run this script from the SOL-Setup repository root"
        exit 1
    fi
    
    # Navigate to docker directory
    if [ -f "Makefile" ]; then
        cd docker
    elif [ -f "../Makefile" ]; then
        cd ../docker
    fi
    
    if [ ! -f "cloudflared/config.yml" ]; then
        error "cloudflared/config.yml not found"
        exit 1
    fi
}

# Parse cloudflared config and extract routes
parse_cloudflared_routes() {
    local config_file="cloudflared/config.yml"
    local routes=()
    
    log "Parsing routes from $config_file..."
    
    # Extract hostname and service pairs from ingress section
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*hostname:[[:space:]]*(.+)$ ]]; then
            hostname="${BASH_REMATCH[1]}"
            # Read the next line for service
            read -r service_line
            if [[ "$service_line" =~ ^[[:space:]]*service:[[:space:]]*(.+)$ ]]; then
                service="${BASH_REMATCH[1]}"
                # Only add HTTP services (skip http_status entries)
                if [[ "$service" =~ ^https?:// ]]; then
                    routes+=("$hostname|$service")
                fi
            fi
        fi
    done < "$config_file"
    
    if [ ${#routes[@]} -eq 0 ]; then
        warn "No HTTP routes found in cloudflared configuration"
        return 1
    fi
    
    success "Found ${#routes[@]} routes to test"
    printf '%s\n' "${routes[@]}"
}

# Test local service connectivity
test_local_service() {
    local service_url="$1"
    local hostname="$2"
    local timeout=5
    
    # Extract host and port from URL
    if [[ "$service_url" =~ ^https?://([^:/]+):?([0-9]+)?/?.*$ ]]; then
        local host="${BASH_REMATCH[1]}"
        local port="${BASH_REMATCH[2]:-80}"
        
        # Override port for HTTPS if not specified
        if [[ "$service_url" =~ ^https:// ]] && [ -z "${BASH_REMATCH[2]}" ]; then
            port=443
        fi
        
        # Test basic connectivity
        if timeout "$timeout" bash -c "</dev/tcp/$host/$port" 2>/dev/null; then
            # Try HTTP request
            local http_status
            http_status=$(curl -s -o /dev/null -w "%{http_code}" -m "$timeout" -L \
                --connect-timeout 3 \
                --user-agent "SOL-Homelab-Route-Test" \
                "$service_url" 2>/dev/null || echo "000")
            
            case "$http_status" in
                200|201|202|301|302|307|308)
                    echo -e "${GREEN}✓${NC} $hostname → $service_url (HTTP $http_status)"
                    return 0
                    ;;
                401|403)
                    echo -e "${YELLOW}⚠${NC} $hostname → $service_url (HTTP $http_status - Auth required)"
                    return 0
                    ;;
                404|500|502|503)
                    echo -e "${RED}✗${NC} $hostname → $service_url (HTTP $http_status - Service error)"
                    return 1
                    ;;
                000)
                    echo -e "${RED}✗${NC} $hostname → $service_url (Connection failed)"
                    return 1
                    ;;
                *)
                    echo -e "${YELLOW}?${NC} $hostname → $service_url (HTTP $http_status - Unknown)"
                    return 1
                    ;;
            esac
        else
            echo -e "${RED}✗${NC} $hostname → $service_url (Port $port not reachable)"
            return 1
        fi
    else
        echo -e "${RED}✗${NC} $hostname → $service_url (Invalid URL format)"
        return 1
    fi
}

# Generate success URLs
generate_success_urls() {
    local routes=("$@")
    local external_urls=()
    local working_routes=0
    
    echo ""
    echo -e "${GREEN}🎉 Success! Your homelab is accessible at these URLs:${NC}"
    echo "=================================================="
    
    for route in "${routes[@]}"; do
        IFS='|' read -r hostname service <<< "$route"
        
        # Test if local service is working
        if test_local_service "$service" "$hostname" >/dev/null 2>&1; then
            echo -e "${GREEN}✓${NC} https://$hostname"
            external_urls+=("https://$hostname")
            ((working_routes++))
        else
            echo -e "${YELLOW}⚠${NC} https://$hostname (local service may be starting up)"
        fi
    done
    
    echo ""
    if [ ${#external_urls[@]} -gt 0 ]; then
        echo "Key services:"
        for url in "${external_urls[@]}"; do
            case "$url" in
                *dash.*)     echo "  🏠 Dashboard: $url" ;;
                *plex.*)     echo "  🎬 Media:     $url" ;;
                *portainer.*) echo "  🐳 Docker:    $url" ;;
                *dns.*)      echo "  🛡️  DNS:       $url" ;;
            esac
        done | head -4
    fi
    
    echo ""
    echo "📊 Summary: $working_routes routes tested and accessible"
    
    if [ "$working_routes" -lt "${#routes[@]}" ]; then
        echo ""
        warn "Some services may still be starting up. Wait a few minutes and test again."
    fi
}

# Main function
main() {
    log "Starting SOL Homelab route testing..."
    
    check_working_directory
    
    # Parse routes from cloudflared config
    local routes_output
    routes_output=$(parse_cloudflared_routes) || exit 1
    
    local routes=()
    while IFS= read -r line; do
        [ -n "$line" ] && routes+=("$line")
    done <<< "$routes_output"
    
    echo ""
    log "Testing local service connectivity..."
    echo ""
    
    local failed_tests=0
    
    # Test each route
    for route in "${routes[@]}"; do
        IFS='|' read -r hostname service <<< "$route"
        if ! test_local_service "$service" "$hostname"; then
            ((failed_tests++))
        fi
    done
    
    echo ""
    
    if [ "$failed_tests" -eq 0 ]; then
        success "All routes tested successfully!"
        generate_success_urls "${routes[@]}"
    elif [ "$failed_tests" -lt "${#routes[@]}" ]; then
        warn "$failed_tests of ${#routes[@]} routes failed"
        log "Some services may still be starting up or have configuration issues"
        generate_success_urls "${routes[@]}"
    else
        error "All route tests failed"
        error "Check if Docker services are running: docker compose ps"
        exit 1
    fi
}

# Handle script interruption
trap 'error "Route testing interrupted"; exit 1' INT TERM

# Run main function
main "$@"
