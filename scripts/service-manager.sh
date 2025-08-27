#!/usr/bin/env bash
set -euo pipefail

# SOL Homelab Service Manager
# Provides easy management of service groups and individual services

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DOCKER_DIR="$PROJECT_ROOT/docker"

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
    if [ ! -d "$DOCKER_DIR" ]; then
        error "Docker directory not found. Run this script from the project root."
        exit 1
    fi
    
    cd "$DOCKER_DIR"
}

# Show service status
show_status() {
    log "Service Status:"
    echo "=================="
    docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
}

# Start services by group
start_group() {
    local group="$1"
    log "Starting $group services..."
    
    case "$group" in
        "media")
            docker compose up -d plex sonarr radarr prowlarr bazarr overseerr tautulli
            ;;
        "vpn")
            docker compose up -d gluetun qbittorrent
            ;;
        "monitoring")
            docker compose up -d glances uptime-kuma dozzle prometheus grafana loki promtail node-exporter cadvisor
            ;;
        "infrastructure")
            docker compose up -d cloudflared adguardhome portainer homarr n8n watchtower
            ;;
        "all")
            docker compose up -d
            ;;
        *)
            error "Unknown service group: $group"
            echo "Available groups: media, vpn, monitoring, infrastructure, all"
            exit 1
            ;;
    esac
    
    success "$group services started"
}

# Stop services by group
stop_group() {
    local group="$1"
    log "Stopping $group services..."
    
    case "$group" in
        "media")
            docker compose stop plex sonarr radarr prowlarr bazarr overseerr tautulli
            ;;
        "vpn")
            docker compose stop gluetun qbittorrent
            ;;
        "monitoring")
            docker compose stop glances uptime-kuma dozzle prometheus grafana loki promtail node-exporter cadvisor
            ;;
        "infrastructure")
            docker compose stop cloudflared adguardhome portainer homarr n8n watchtower
            ;;
        "all")
            docker compose stop
            ;;
        *)
            error "Unknown service group: $group"
            echo "Available groups: media, vpn, monitoring, infrastructure, all"
            exit 1
            ;;
    esac
    
    success "$group services stopped"
}

# Restart services by group
restart_group() {
    local group="$1"
    log "Restarting $group services..."
    
    case "$group" in
        "media")
            docker compose restart plex sonarr radarr prowlarr bazarr overseerr tautulli
            ;;
        "vpn")
            docker compose restart gluetun qbittorrent
            ;;
        "monitoring")
            docker compose restart glances uptime-kuma dozzle prometheus grafana loki promtail node-exporter cadvisor
            ;;
        "infrastructure")
            docker compose restart cloudflared adguardhome portainer homarr n8n watchtower
            ;;
        "all")
            docker compose restart
            ;;
        *)
            error "Unknown service group: $group"
            echo "Available groups: media, vpn, monitoring, infrastructure, all"
            exit 1
            ;;
    esac
    
    success "$group services restarted"
}

# Show logs for services
show_logs() {
    local service="$1"
    local lines="${2:-50}"
    
    if [ -z "$service" ]; then
        log "Showing logs for all services (last $lines lines)..."
        docker compose logs --tail="$lines" -f
    else
        log "Showing logs for $service (last $lines lines)..."
        docker compose logs --tail="$lines" -f "$service"
    fi
}

# Update services
update_services() {
    local group="$1"
    log "Updating $group services..."
    
    case "$group" in
        "media")
            docker compose pull plex sonarr radarr prowlarr bazarr overseerr tautulli
            docker compose up -d plex sonarr radarr prowlarr bazarr overseerr tautulli
            ;;
        "vpn")
            docker compose pull gluetun qbittorrent
            docker compose up -d gluetun qbittorrent
            ;;
        "monitoring")
            docker compose pull glances uptime-kuma dozzle prometheus grafana loki promtail node-exporter cadvisor
            docker compose up -d glances uptime-kuma dozzle prometheus grafana loki promtail node-exporter cadvisor
            ;;
        "infrastructure")
            docker compose pull cloudflared adguardhome portainer homarr n8n watchtower
            docker compose up -d cloudflared adguardhome portainer homarr n8n watchtower
            ;;
        "all")
            docker compose pull
            docker compose up -d
            ;;
        *)
            error "Unknown service group: $group"
            echo "Available groups: media, vpn, monitoring, infrastructure, all"
            exit 1
            ;;
    esac
    
    success "$group services updated"
}

# Show resource usage
show_resources() {
    log "Resource Usage:"
    echo "=================="
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"
}

# Show service information
show_info() {
    local service="$1"
    
    if [ -z "$service" ]; then
        log "Service Information:"
        echo "====================="
        docker compose ps
        echo ""
        log "Service Groups:"
        echo "==============="
        echo "media: Plex, Sonarr, Radarr, Prowlarr, Bazarr, Overseerr, Tautulli"
        echo "vpn: Gluetun, qBittorrent"
        echo "monitoring: Glances, Uptime-Kuma, Dozzle, Prometheus, Grafana, Loki, Promtail, Node Exporter, cAdvisor"
        echo "infrastructure: Cloudflare Tunnel, AdGuard Home, Portainer, Homarr, n8n, Watchtower"
    else
        log "Information for $service:"
        echo "========================"
        docker compose ps "$service"
        echo ""
        docker compose logs --tail=10 "$service"
    fi
}

# Show help
show_help() {
    echo "SOL Homelab Service Manager"
    echo "==========================="
    echo ""
    echo "Usage: $0 [COMMAND] [SERVICE_GROUP] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  status                    Show status of all services"
    echo "  start [GROUP]            Start services by group"
    echo "  stop [GROUP]             Stop services by group"
    echo "  restart [GROUP]          Restart services by group"
    echo "  update [GROUP]           Update and restart services by group"
    echo "  logs [SERVICE] [LINES]   Show logs (default: 50 lines)"
    echo "  resources                Show resource usage"
    echo "  info [SERVICE]           Show service information"
    echo "  help                     Show this help message"
    echo ""
    echo "Service Groups:"
    echo "  media                    Media pipeline services"
    echo "  vpn                      VPN and torrent services"
    echo "  monitoring               Monitoring and logging services"
    echo "  infrastructure           Core infrastructure services"
    echo "  all                      All services"
    echo ""
    echo "Examples:"
    echo "  $0 status"
    echo "  $0 start media"
    echo "  $0 restart monitoring"
    echo "  $0 logs plex 100"
    echo "  $0 update all"
}

# Main function
main() {
    local command="$1"
    local group="$2"
    local service="$3"
    
    # Check environment
    check_environment
    
    case "$command" in
        "status")
            show_status
            ;;
        "start")
            if [ -z "$group" ]; then
                error "Please specify a service group"
                show_help
                exit 1
            fi
            start_group "$group"
            ;;
        "stop")
            if [ -z "$group" ]; then
                error "Please specify a service group"
                show_help
                exit 1
            fi
            stop_group "$group"
            ;;
        "restart")
            if [ -z "$group" ]; then
                error "Please specify a service group"
                show_help
                exit 1
            fi
            restart_group "$group"
            ;;
        "update")
            if [ -z "$group" ]; then
                error "Please specify a service group"
                show_help
                exit 1
            fi
            update_services "$group"
            ;;
        "logs")
            show_logs "$group" "$service"
            ;;
        "resources")
            show_resources
            ;;
        "info")
            show_info "$group"
            ;;
        "help"|"--help"|"-h"|"")
            show_help
            ;;
        *)
            error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Handle script interruption
trap 'error "Service management interrupted"; exit 1' INT TERM

# Run main function
main "$@"
