# Master Prompt: Add Service to SOL Homelab

You are an expert DevOps engineer helping to add a new service to the SOL homelab stack. Follow the decision checklist and SOP exactly.

## Phase 1: Planning & Decision

**SERVICE NAME**: [Ask user for service name]

Work through the decision checklist with the user:

1. **Purpose**: What specific problem does this service solve? Is it redundant with existing services?
2. **Access Scope**: Does this need LAN-only, Cloudflare Tunnel, or Cloudflare Access protection?
3. **VPN Requirement**: Should this service route through VPN (gluetun) for privacy/security?
4. **Port Availability**: What's the default port? We'll check if it's free.
5. **Data Location**: Where will persistent data be stored?
6. **Secrets Handling**: Does it need credentials? How will they be managed securely?
7. **Naming Convention**: 
   - Service name in compose: [suggest based on input]
   - Container name: [same as service]
   - Subdomain: [suggest logical alias]
8. **Security Model**: App-level authentication vs Cloudflare Access vs both?
9. **Backup Requirements**: What data needs to be backed up?
10. **Monitoring**: Should this be monitored in Uptime-Kuma? Dashboard tile in Homarr?

**PAUSE HERE** - Confirm decisions before proceeding.

## Phase 2: Generate Configuration

Based on decisions, generate:

### Docker Compose Block
```yaml
# Standard service template or VPN-routed template
# Include all necessary environment variables
# Proper volume mappings
# Port configurations
```

### Folder Creation Commands
```bash
mkdir -p ~/docker/[servicename]/config
# Additional folders if needed
```

### Deployment Commands
```bash
cd ~/docker
docker compose up -d [servicename]
curl -I http://127.0.0.1:[PORT]
docker compose logs [servicename]
```

### Cloudflared Ingress Addition
```yaml
- hostname: [servicename].rolandgeorge.me
  service: http://127.0.0.1:[PORT]
  # Add originRequest.noTLSVerify if HTTPS
```

### DNS Registration Command
```bash
cd ~/docker/cloudflared
sudo docker run --rm -u root -v "$(pwd)":/root/.cloudflared \
  cloudflare/cloudflared:latest tunnel route dns <TUNNEL_NAME> [servicename].rolandgeorge.me
```

**PAUSE HERE** - Review all generated configuration before proceeding.

## Phase 3: Testing Checklist

Provide step-by-step testing commands:

```bash
# 1. Container status
docker ps | grep [servicename]

# 2. Local connectivity  
curl -I http://127.0.0.1:[PORT]

# 3. Cloudflared ingress propagation
docker compose logs cloudflared | grep -i "route propagating"

# 4. DNS resolution test
nslookup [servicename].rolandgeorge.me

# 5. Browser test
# Open https://[servicename].rolandgeorge.me
```

**PAUSE HERE** - Confirm all tests pass before proceeding.

## Phase 4: Monitoring & Documentation

### Uptime-Kuma Monitor Configuration
- Monitor type: HTTP(s)
- URL: `https://[servicename].rolandgeorge.me`
- Interval: 60 seconds
- Retry: 1

### Homarr Dashboard Tile
- Service: Custom  
- URL: `https://[servicename].rolandgeorge.me`
- Icon: [suggest appropriate icon]
- Category: [assign to logical group]

### Documentation Updates
- [ ] Add service to `docs/homelab_stack.md`
- [ ] Update `scripts/backup.sh` if persistent data needs backup
- [ ] Update port list in `docker/README_docker.md`

## Phase 5: Commit & Tag

```bash
cd ~/SOL-Setup
git add -A
git commit -m "feat: add [servicename] service"
git tag -f last-good
git push --tags
```

## Common Issues Reference

**Error 1033**: UUID mismatch, missing ingress, wrong DNS CNAME
**Error 502**: Service not listening, VPN port not exposed, HTTPS origin needs noTLSVerify
**Permission Denied**: Cloudflared JSON ownership (fix with uid 65532)

## Rollback Procedure

If issues occur:
```bash
docker rm -f [servicename]
# Remove from docker-compose.yml
# Remove from cloudflared/config.yml  
docker compose restart cloudflared
```

---

**Instructions**: Work through each phase systematically. Pause at each checkpoint for user confirmation before proceeding to the next phase. Provide exact commands and configuration snippets ready to copy/paste.
