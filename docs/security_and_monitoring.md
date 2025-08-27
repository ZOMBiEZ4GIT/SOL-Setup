# Security and Monitoring Guide

## Overview

This document details the security features, health monitoring, and resource management implemented in the SOL homelab Docker stack.

## Security Features

### Container Security Constraints

All containers (except those requiring elevated privileges) run with enhanced security:

```yaml
security_opt: ["no-new-privileges:true"]
```

**What this does:**
- Prevents containers from gaining new privileges during runtime
- Blocks privilege escalation attacks
- Enhances container isolation

**Exceptions:**
- `gluetun`: Requires `NET_ADMIN` capability for VPN functionality
- `glances`: Uses `pid: host` for system monitoring

### Capability Management

Only essential capabilities are granted:

```yaml
# gluetun - VPN container
cap_add: [ NET_ADMIN ]
devices: [ "/dev/net/tun" ]

# glances - System monitoring
pid: host
```

### Network Security

- **Host networking**: Limited to essential services (Plex, AdGuard, Cloudflared)
- **Service isolation**: Most services use bridge networking
- **VPN routing**: qBittorrent traffic routed through secure VPN tunnel

## Health Monitoring

### Health Check Configuration

All services include comprehensive health checks:

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://127.0.0.1:PORT/endpoint"]
  interval: 30s      # Check every 30 seconds
  timeout: 10s       # 10 second timeout
  retries: 3         # 3 failures before unhealthy
  start_period: 60s  # 60 second grace period
```

### Health Check Endpoints

| Service | Endpoint | Purpose |
|---------|----------|---------|
| Plex | `/web/index.html` | Web interface availability |
| n8n | `/healthz` | API health status |
| Sonarr | `/health` | Service health |
| Radarr | `/health` | Service health |
| Homarr | `/api/health` | Dashboard health |
| Portainer | `/api/status` | Management interface status |
| Gluetun | `/v1/openvpn/status` | VPN connection status |
| qBittorrent | `/api/v2/app/version` | Torrent client status |
| Prowlarr | `/health` | Indexer health |
| Bazarr | `/health` | Subtitle service health |
| Overseerr | `/health` | Request service health |
| Tautulli | `/status` | Analytics service health |
| Glances | `/api/3/status` | System monitoring status |
| Uptime-Kuma | `/` | Uptime monitoring status |
| Dozzle | `/` | Log viewer status |
| AdGuard Home | `/control/status` | DNS service status |

### Health Check Benefits

- **Early failure detection**: Identify issues before users report them
- **Load balancer integration**: Unhealthy containers can be automatically removed
- **Monitoring integration**: Health status feeds into monitoring systems
- **Automated recovery**: Can trigger restart policies

## Resource Management

### Resource Limits

Prevents resource exhaustion and ensures fair allocation:

```yaml
deploy:
  resources:
    limits:
      memory: 2G        # Maximum memory usage
      cpus: '1.0'       # Maximum CPU usage (1 full core)
    reservations:
      memory: 512M      # Guaranteed memory allocation
      cpus: '0.25'      # Guaranteed CPU allocation (0.25 cores)
```

### Resource Allocation Strategy

#### High-Resource Services
- **Plex**: 2GB memory, 1.0 CPU (media transcoding)
- **n8n**: 1GB memory, 0.5 CPU (workflow automation)
- **qBittorrent**: 1GB memory, 0.5 CPU (download management)

#### Medium-Resource Services
- **Sonarr/Radarr**: 512MB memory, 0.5 CPU (media management)
- **Prowlarr/Bazarr**: 512MB memory, 0.5 CPU (indexing/subtitles)
- **Overseerr**: 512MB memory, 0.5 CPU (request management)

#### Light-Resource Services
- **Homarr**: 256MB memory, 0.25 CPU (dashboard)
- **Portainer**: 256MB memory, 0.25 CPU (Docker management)
- **Monitoring tools**: 256MB memory, 0.25 CPU (Glances, Uptime-Kuma, etc.)

### Resource Management Benefits

- **Prevents resource exhaustion**: No single service can consume all resources
- **Predictable performance**: Guaranteed minimum resources for critical services
- **Cost optimization**: Efficient resource utilization
- **Stability**: Prevents cascading failures from resource contention

## Monitoring Integration

### Docker Health Status

View health status of all containers:

```bash
docker compose ps
```

### Health Check Logs

Monitor health check results:

```bash
docker compose logs -f | grep -E "(health|unhealthy|healthy)"
```

### Resource Usage Monitoring

Monitor resource consumption:

```bash
# Memory usage
docker stats --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"

# Resource limits
docker inspect <container> | grep -A 10 "HostConfig"
```

### Integration with Monitoring Stack

Health checks integrate with existing monitoring:

- **Uptime-Kuma**: Can use health check endpoints for external monitoring
- **Glances**: System-level resource monitoring
- **Portainer**: Container health status in web interface
- **Homarr**: Dashboard integration for service status

## Troubleshooting

### Common Health Check Issues

#### Service Not Responding
```bash
# Check if service is listening
curl -f http://127.0.0.1:PORT/endpoint

# Check container logs
docker compose logs -f servicename
```

#### Resource Limit Issues
```bash
# Check resource usage
docker stats servicename

# Check if limits are being hit
docker inspect servicename | grep -A 5 "HostConfig"
```

#### Security Constraint Issues
```bash
# Check security options
docker inspect servicename | grep -A 5 "SecurityOpt"

# Verify no privilege escalation
docker exec servicename whoami
```

### Health Check Customization

Customize health checks for specific needs:

```yaml
healthcheck:
  test: ["CMD", "custom-health-script.sh"]
  interval: 60s        # Less frequent for stable services
  timeout: 15s         # Longer timeout for slow services
  retries: 5           # More retries for flaky services
  start_period: 120s   # Longer startup for complex services
```

## Best Practices

### Security
- Always use `no-new-privileges` unless absolutely necessary
- Limit capabilities to minimum required
- Use read-only volumes where possible
- Implement network segmentation

### Health Checks
- Use lightweight endpoints for health checks
- Avoid heavy operations in health check commands
- Set appropriate intervals based on service characteristics
- Monitor health check performance impact

### Resource Management
- Set realistic limits based on actual usage patterns
- Monitor resource utilization over time
- Adjust limits based on performance requirements
- Use reservations for critical services

## Future Enhancements

### Planned Improvements
- **Secrets management**: Integration with HashiCorp Vault or Docker secrets
- **Network policies**: More granular network security rules
- **Audit logging**: Container security event logging
- **Automated scanning**: Security vulnerability scanning in CI/CD
- **Compliance monitoring**: Automated compliance checking

### Monitoring Enhancements
- **Metrics collection**: Prometheus integration for detailed metrics
- **Alerting**: Automated alerting for security and health issues
- **Dashboard**: Centralized security and health monitoring dashboard
- **Reporting**: Automated security and health reports
