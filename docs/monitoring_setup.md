# Monitoring & Logging Setup Guide

## Overview

The SOL homelab includes a comprehensive monitoring and logging stack:

- **Loki**: Centralized log aggregation
- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization and dashboards
- **Watchtower**: Automated container updates

## Quick Start

### 1. Deploy the Stack

```bash
cd docker
docker compose up -d loki promtail grafana prometheus node-exporter cadvisor watchtower
```

### 2. Access Services

- **Grafana**: http://localhost:3000 (admin / admin_change_me)
- **Prometheus**: http://localhost:9090
- **Loki**: http://localhost:3100

### 3. Initial Grafana Setup

1. Login with admin / admin_change_me
2. Add data sources:
   - **Prometheus**: http://prometheus:9090
   - **Loki**: http://loki:3100

## Logging Stack (Loki)

### Architecture

```
Services → Loki Driver → Loki → Grafana
    ↓
Promtail → System Logs → Loki
```

### Configuration

**Loki** (`docker/loki/local-config.yaml`):
- Single-node setup for homelab use
- File-based storage (./loki directory)
- 7-day log retention

**Promtail** (`docker/promtail/config.yml`):
- Collects Docker container logs
- Collects system logs (/var/log)
- Forwards to Loki with structured labels

### Log Queries

In Grafana, query logs with LogQL:

```logql
# All logs from a specific service
{service="plex"}

# Error logs from any service
{job="docker"} |= "error"

# Recent logs with time filter
{job="docker"} |~ "(?i)error|warn|fail" [5m]

# Structured log queries
{service="sonarr"} | json | level="error"
```

### Log Labels

Each service includes structured labels:
- `service`: Service name (plex, sonarr, etc.)
- `environment`: homelab
- `level`: Log level (if available)
- `stream`: stdout/stderr

## Metrics Stack (Prometheus)

### Architecture

```
Services → Prometheus → Grafana
    ↓
Node Exporter → Host Metrics
cAdvisor → Container Metrics
```

### Data Sources

**Prometheus** collects metrics from:
- **Node Exporter**: Host system metrics
- **cAdvisor**: Container resource usage
- **Services**: Application metrics (if available)

**Key Metrics**:
- CPU, memory, disk usage
- Network I/O
- Container resource consumption
- Service health status

### Prometheus Queries

Example PromQL queries:

```promql
# CPU usage
100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory usage
(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100

# Container memory usage
container_memory_usage_bytes{container!=""}

# Service uptime
up{job="plex"}
```

## Grafana Dashboards

### Pre-built Dashboards

1. **Node Exporter Full**: Host system metrics
2. **Docker & System Monitoring**: Container metrics
3. **Loki Dashboard**: Log visualization

### Custom Dashboards

Create dashboards for:
- **Service Health**: Health check status
- **Resource Usage**: CPU, memory, disk
- **Application Metrics**: Service-specific data
- **Log Analysis**: Error rates, patterns

### Dashboard Variables

Use variables for dynamic dashboards:
```grafana
# Service selection
$service = {plex,sonarr,radarr,n8n}

# Time range
$__timeFilter()
```

## Automated Updates (Watchtower)

### Configuration

Watchtower automatically updates containers every 24 hours:

```yaml
environment:
  - WATCHTOWER_CLEANUP=true          # Remove old images
  - WATCHTOWER_INCLUDE_STOPPED=true  # Update stopped containers
  - WATCHTOWER_REVIVE_STOPPED=true   # Restart stopped containers
  - WATCHTOWER_LABEL_ENABLE=true     # Only update labeled containers
  - WATCHTOWER_POLL_INTERVAL=86400   # 24 hours
```

### Notifications

Configure notifications via Shoutrrr in `.env`:

```bash
# Discord
SHOUTRRR_URL=discord://webhook_id/webhook_token

# Slack
SHOUTRRR_URL=slack://token-a/token-b/token-c

# Email
SHOUTRRR_URL=smtp://username:password@host:port/?from=fromaddress&to=recipient@example.com

# Telegram
SHOUTRRR_URL=telegram://bot_token@telegram/?channels=@channelname
```

### Update Control

Control which containers update:
```yaml
# Add label to enable updates
labels:
  - "com.centurylinklabs.watchtower.enable=true"

# Exclude specific containers
environment:
  - WATCHTOWER_EXCLUDE=plex,adguardhome
```

## Monitoring Best Practices

### 1. Resource Limits

Set appropriate limits for monitoring services:
```yaml
deploy:
  resources:
    limits:
      memory: 512M
      cpus: '0.5'
    reservations:
      memory: 128M
      cpus: '0.1'
```

### 2. Log Retention

Configure log retention based on storage:
```yaml
# Loki config
limits_config:
  reject_old_samples: true
  reject_old_samples_max_age: 168h  # 7 days

# Prometheus config
command:
  - '--storage.tsdb.retention.time=200h'  # 8 days
```

### 3. Health Checks

Monitor monitoring services:
```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:3100/ready"]
  interval: 30s
  timeout: 10s
  retries: 3
```

### 4. Backup Monitoring

Include monitoring configs in backups:
```bash
# Backup monitoring configurations
tar czf monitoring_backup_$(date +%F).tgz \
  docker/loki docker/promtail docker/prometheus docker/grafana
```

## Troubleshooting

### Common Issues

#### Loki Not Collecting Logs
```bash
# Check Promtail status
docker compose logs promtail

# Verify Loki connectivity
curl http://localhost:3100/ready

# Check log driver configuration
docker inspect <container> | grep -A 5 "LogConfig"
```

#### Prometheus Metrics Missing
```bash
# Check target status
curl http://localhost:9090/api/v1/targets

# Verify service endpoints
curl http://localhost:9100/metrics  # Node Exporter
curl http://localhost:8080/metrics  # cAdvisor
```

#### Grafana Connection Issues
```bash
# Check data source URLs
# Use service names, not localhost
# Prometheus: http://prometheus:9090
# Loki: http://loki:3100

# Verify network connectivity
docker compose exec grafana ping prometheus
docker compose exec grafana ping loki
```

#### Watchtower Not Updating
```bash
# Check logs
docker compose logs watchtower

# Verify Docker socket access
docker compose exec watchtower ls -la /var/run/docker.sock

# Check notification configuration
echo $SHOUTRRR_URL
```

### Performance Tuning

#### High Log Volume
```yaml
# Increase Promtail resources
deploy:
  resources:
    limits:
      memory: 1G
      cpus: '1.0'

# Adjust Loki chunk settings
ingester:
  chunk_idle_period: 1m
  chunk_retain_period: 15s
```

#### High Metrics Volume
```yaml
# Increase Prometheus resources
deploy:
  resources:
    limits:
      memory: 1G
      cpus: '1.0'

# Adjust scrape intervals
global:
  scrape_interval: 30s  # Default: 15s
```

## Integration Examples

### 1. Uptime-Kuma Integration

Use health check endpoints for external monitoring:
```yaml
# Uptime-Kuma configuration
- name: "Plex Health"
  url: "http://127.0.0.1:32400/web/index.html"
  interval: 60

- name: "Sonarr Health"
  url: "http://127.0.0.1:8989/health"
  interval: 60
```

### 2. Homarr Dashboard

Add monitoring services to Homarr:
```yaml
# Grafana
- name: "Grafana"
  url: "http://grafana:3000"
  icon: "mdi-chart-line"

# Prometheus
- name: "Prometheus"
  url: "http://prometheus:9090"
  icon: "mdi-database"
```

### 3. Custom Alerts

Create Grafana alerts for:
- Service health status
- Resource usage thresholds
- Error log patterns
- Update failures

## Future Enhancements

### Planned Improvements
- **Alert Manager**: Advanced alerting rules
- **Service Mesh**: Istio/Linkerd integration
- **Distributed Tracing**: Jaeger integration
- **Custom Dashboards**: Pre-built service dashboards
- **Metrics Exporters**: Service-specific exporters

### Scaling Considerations
- **Multi-node Loki**: For high-volume logging
- **Prometheus Federation**: For multiple homelabs
- **Remote Storage**: S3-compatible storage for metrics
- **Load Balancing**: HAProxy/Traefik for monitoring services

## Support

- **Documentation**: This guide and inline comments
- **Configuration**: Check service-specific config files
- **Logs**: Use `docker compose logs <service>`
- **Metrics**: Query Prometheus directly
- **Community**: Docker, Prometheus, and Grafana communities
