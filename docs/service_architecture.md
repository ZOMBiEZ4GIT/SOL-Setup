# SOL Homelab Service Architecture

## Overview

The SOL Homelab has been restructured to use a modular service architecture that provides better organization, easier management, and improved scalability.

## Architecture Principles

### 1. **Service Grouping**
- **Logical Separation**: Services are grouped by function and purpose
- **Independent Management**: Each group can be managed independently
- **Resource Optimization**: Resource limits are tailored to service groups
- **Easier Maintenance**: Updates and maintenance can be performed per group

### 2. **Modular Design**
- **Main Orchestrator**: `docker-compose.yml` orchestrates all services
- **Service Files**: Individual service definitions in `services/` directory
- **Shared Configuration**: Common settings and resource limits
- **Network Isolation**: Future capability for network segmentation

## Service Groups

### 1. **Media Pipeline (`media.yml`)**

**Purpose**: Core media management and automation services

**Services**:
- **Plex**: Media server (host networking, no CPU limits)
- **Sonarr**: TV show automation
- **Radarr**: Movie automation
- **Prowlarr**: Indexer management
- **Bazarr**: Subtitle management
- **Overseerr**: Request management
- **Tautulli**: Analytics and monitoring

**Characteristics**:
- High I/O operations
- Media processing workloads
- User-facing interfaces
- Integration with external APIs

**Resource Profile**:
- **Plex**: 2GB memory, no CPU limits (transcoding)
- **Others**: 512MB memory, 0.5 CPU

### 2. **VPN Services (`vpn.yml`)**

**Purpose**: Secure VPN routing and torrent services

**Services**:
- **Gluetun**: ProtonVPN client with kill switch
- **qBittorrent**: Torrent client routed through VPN

**Characteristics**:
- Network-intensive operations
- Security-critical services
- Requires elevated privileges (NET_ADMIN)
- Traffic isolation

**Resource Profile**:
- **Gluetun**: 256MB memory, 0.25 CPU
- **qBittorrent**: 1GB memory, 0.5 CPU

### 3. **Monitoring & Logging (`monitoring.yml`)**

**Purpose**: System monitoring, metrics, and log aggregation

**Services**:
- **Glances**: System resource monitoring
- **Uptime-Kuma**: Service availability monitoring
- **Dozzle**: Real-time log viewer
- **Prometheus**: Metrics collection
- **Grafana**: Metrics visualization
- **Loki**: Log aggregation
- **Promtail**: Log collection
- **Node Exporter**: Host metrics
- **cAdvisor**: Container metrics

**Characteristics**:
- Data collection and storage
- Visualization and alerting
- Historical data retention
- Resource monitoring

**Resource Profile**:
- **Prometheus/Grafana/Loki**: 512MB memory, 0.5 CPU
- **Others**: 256MB memory, 0.25 CPU

### 4. **Infrastructure (`infrastructure.yml`)**

**Purpose**: Core infrastructure and management services

**Services**:
- **Cloudflare Tunnel**: Secure external access
- **AdGuard Home**: DNS filtering and ad blocking
- **Portainer**: Docker management interface
- **Homarr**: Homelab dashboard
- **n8n**: Workflow automation
- **Watchtower**: Automated container updates

**Characteristics**:
- Core system services
- Security and access control
- Management interfaces
- Automation and orchestration

**Resource Profile**:
- **n8n**: 1GB memory, 0.5 CPU
- **Others**: 256MB memory, 0.25 CPU

## Resource Management

### 1. **Memory Limits**

| Service Group | Memory Limit | Rationale |
|---------------|--------------|-----------|
| **Plex** | 2GB | Transcoding and media processing |
| **Media Services** | 512MB | Automation and API operations |
| **VPN Services** | 256MB-1GB | Network operations and caching |
| **Monitoring** | 256MB-512MB | Data collection and storage |
| **Infrastructure** | 256MB-1GB | Management and automation |

### 2. **CPU Limits**

| Service Group | CPU Limit | Rationale |
|---------------|-----------|-----------|
| **Plex** | No limit | Prevent transcoding throttling |
| **Media Services** | 0.5 CPU | Balanced performance |
| **VPN Services** | 0.25-0.5 CPU | Network processing |
| **Monitoring** | 0.25-0.5 CPU | Data collection |
| **Infrastructure** | 0.25-0.5 CPU | Management operations |

### 3. **Resource Reservations**

All services have resource reservations to ensure minimum performance:
- **Memory**: 64MB-512MB based on service type
- **CPU**: 0.05-0.25 CPU cores for basic operation

## Network Architecture

### 1. **Current Network Model**

- **Host Networking**: Plex, AdGuard Home, Cloudflare Tunnel
- **Bridge Networking**: All other services
- **Service Networking**: qBittorrent uses gluetun network

### 2. **Future Network Segmentation**

Planned network isolation for security:

```yaml
networks:
  default:          # General services
  monitoring:       # Monitoring stack (internal)
  media:           # Media services (internal)
  vpn:             # VPN services (isolated)
  infrastructure:   # Core services (restricted)
```

## Service Dependencies

### 1. **Startup Order**

1. **Infrastructure**: Cloudflare Tunnel, AdGuard Home
2. **VPN**: Gluetun (required for qBittorrent)
3. **Monitoring**: Loki, Prometheus, Grafana
4. **Media**: All media services
5. **Management**: Portainer, Homarr, n8n

### 2. **Health Checks**

All services include health checks:
- **Interval**: 30 seconds
- **Timeout**: 10 seconds
- **Retries**: 3 attempts
- **Start Period**: 60 seconds grace period

## Management Commands

### 1. **Service Group Operations**

```bash
# Start services by group
make start GROUP=media
make start GROUP=monitoring
make start GROUP=all

# Stop services by group
make stop GROUP=vpn
make stop GROUP=infrastructure

# Restart services by group
make restart GROUP=media
make restart GROUP=monitoring

# Update services by group
make update GROUP=all
make update GROUP=media
```

### 2. **Service Information**

```bash
# Show all services
make status

# Show resource usage
make resources

# Show service information
make info
make info SERVICE=plex
```

### 3. **Direct Script Usage**

```bash
# Service management
bash scripts/service-manager.sh start media
bash scripts/service-manager.sh restart monitoring
bash scripts/service-manager.sh logs plex 100

# Deployment
bash scripts/deploy.sh
bash scripts/validate.sh
```

## Benefits of New Architecture

### 1. **Operational Benefits**

- **Easier Management**: Start/stop/restart services by group
- **Selective Updates**: Update only specific service groups
- **Better Monitoring**: Group-based resource monitoring
- **Simplified Troubleshooting**: Isolate issues to specific groups

### 2. **Maintenance Benefits**

- **Reduced Downtime**: Update services without full restart
- **Rolling Updates**: Update services incrementally
- **Easier Testing**: Test changes on specific groups
- **Better Resource Control**: Optimize resources per group

### 3. **Scalability Benefits**

- **Service Addition**: Easy to add new services to groups
- **Resource Scaling**: Adjust resources per group
- **Network Isolation**: Future network segmentation capability
- **Load Distribution**: Distribute load across service groups

## Future Enhancements

### 1. **Network Segmentation**

- Implement network isolation between service groups
- Add firewall rules per network
- Implement service-to-service communication controls

### 2. **Resource Optimization**

- Dynamic resource allocation based on usage
- Auto-scaling for high-demand services
- Resource usage analytics and optimization

### 3. **Service Discovery**

- Implement service discovery mechanisms
- Dynamic service registration
- Health check aggregation and alerting

---

**Last Updated**: $(date +%Y-%m-%d)  
**Next Review**: Monthly  
**Owner**: System Administrator
