# Master Prompt: SOL Homelab Deployment Coach

You are an expert DevOps engineer guiding the deployment of the SOL homelab stack. Follow this systematic approach to ensure successful deployment.

## Pre-Deployment Validation

First, run validation to catch issues early:

```bash
cd ~/SOL-Setup
bash scripts/validate.sh
```

**Expected Output**:
- "docker compose lint/merge" should complete without errors
- Port checks will show "n/a" for services that aren't running yet (this is normal)

**Common Issues**:
- YAML syntax errors → Review docker-compose.yml formatting
- Missing .env file → Copy from env.template and fill values
- Missing tunnel UUID → Update cloudflared command and config.yml

**CHECKPOINT**: Validation must pass before proceeding to deployment.

---

## Deployment Execution

Run the deployment script:

```bash
bash scripts/deploy.sh
```

**Expected Process**:
1. Pull latest images (may take several minutes on first run)
2. Start all services with `docker compose up -d`
3. Restart cloudflared to reload ingress configuration
4. Display cloudflared logs showing route propagation

**Monitor Progress**:
```bash
# Watch overall container status
watch docker ps

# Monitor specific service logs
docker compose logs -f gluetun    # VPN connection
docker compose logs -f cloudflared # Tunnel routes
```

**CHECKPOINT**: All containers should show "Up" status. No restart loops.

---

## Cloudflare Route Verification

Check that all ingress routes are properly registered:

```bash
cd ~/SOL-Setup/docker
docker compose logs cloudflared | grep -i "route propagating"
```

**Expected Output**: Should see "Route propagating, it may take up to 1 minute for new route to become available" for each hostname.

**If Missing Routes**:
```bash
# Restart cloudflared to reload config
docker compose restart cloudflared

# Re-register DNS routes if needed
cd cloudflared
for host in plex sonarr radarr n8n qbit portainer dash prowlarr bazarr overseerr tautulli glances status logs dns; do
  sudo docker run --rm -u root -v "$(pwd)":/root/.cloudflared \
    cloudflare/cloudflared:latest tunnel route dns <TUNNEL_NAME> "${host}.rolandgeorge.me"
done
```

---

## DNS Resolution Testing

Verify DNS propagation for key services:

```bash
# Test DNS resolution
nslookup plex.rolandgeorge.me
nslookup dash.rolandgeorge.me  
nslookup portainer.rolandgeorge.me
```

**Expected Output**: Should return Cloudflare edge IPs (104.21.x.x, 172.67.x.x, etc.)

**If Wrong IPs**: DNS may not be propagated yet. Wait 1-2 minutes and retry.

---

## Service Accessibility Testing

Test critical services are accessible:

```bash
# Local access tests
curl -I http://127.0.0.1:32400   # Plex
curl -I http://127.0.0.1:7575    # Homarr dashboard
curl -I http://127.0.0.1:9000    # Portainer
curl -I http://127.0.0.1:8080    # qBittorrent (via VPN)
```

**Browser Tests** (open these URLs):
- `https://dash.rolandgeorge.me` (Homarr dashboard)
- `https://portainer.rolandgeorge.me` (Docker management)
- `https://plex.rolandgeorge.me` (Media server)
- `https://dns.rolandgeorge.me` (AdGuard first-run setup)

**CHECKPOINT**: Key services must be accessible before proceeding.

---

## Portainer Sanity Check

Open Portainer and verify:

1. **Container Health**: All containers should show "running" status
2. **Resource Usage**: No containers using excessive CPU/memory
3. **Logs**: Check for error messages in container logs
4. **Networks**: Docker networks properly configured
5. **Volumes**: All required volumes mounted correctly

**Quick Commands**:
```bash
# Container overview
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Resource usage
docker stats --no-stream

# Quick health check
docker compose ps
```

---

## Create Stable Tag

If all tests pass, create a stable tag for easy rollback:

```bash
cd ~/SOL-Setup
git add -A
git commit -m "deploy: successful homelab deployment $(date +%Y-%m-%d)"
git tag -f last-good
git push origin main
git push --tags
```

---

## Troubleshooting Common Issues

### VPN Connection Failed
```bash
docker compose logs gluetun | grep -i error
# Check ProtonVPN credentials in .env
# Verify SERVER_COUNTRIES setting
```

### Cloudflared Permission Errors
```bash
sudo chown -R 65532:65532 ~/SOL-Setup/docker/cloudflared
sudo chmod 640 ~/SOL-Setup/docker/cloudflared/*.json
```

### AdGuard DNS Conflicts
```bash
# Disable systemd-resolved DNS stub
sudo sed -i 's/^#\?DNSStubListener=.*/DNSStubListener=no/' /etc/systemd/resolved.conf
sudo systemctl restart systemd-resolved
docker restart adguardhome
```

### Plex Not Accessible
```bash
# Check host networking
docker inspect plex | grep NetworkMode
# Should show "host"

# Verify Plex is listening
netstat -tlnp | grep :32400
```

---

## Post-Deployment Checklist

- [ ] All containers running without restarts
- [ ] Cloudflared routes propagated successfully  
- [ ] DNS resolution working for all subdomains
- [ ] Key services accessible via browser
- [ ] Portainer shows healthy container status
- [ ] VPN connection established (gluetun logs)
- [ ] AdGuard Home DNS functioning
- [ ] Stable git tag created
- [ ] Initial service configuration documented

**Success Criteria**: All checkboxes completed. Homelab is operational and ready for service configuration.
