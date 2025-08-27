# SOP: Adding a New Service to SOL Homelab

## 0) Decision Checklist

Before adding any new service, work through this checklist:

1. **Purpose**: What specific problem does this service solve? Is it redundant with existing services?
2. **Access Scope**: Does this need LAN-only, Cloudflare Tunnel, or Cloudflare Access protection?
3. **VPN Requirement**: Should this service route through VPN (gluetun) for privacy/security?
4. **Port Availability**: Is the default port free? Check with `netstat -tlnp | grep :PORT`
5. **Data Location**: Where will persistent data be stored? (`./servicename/` or specific host path?)
6. **Secrets Handling**: Does it need credentials? How will they be managed securely?
7. **Naming Convention**: 
   - Service name in compose (lowercase, hyphens)
   - Container name (same as service)
   - Subdomain (matches service name or logical alias)
8. **Security Model**: App-level authentication vs Cloudflare Access vs both?
9. **Backup Requirements**: What data needs to be backed up? Update `backup.sh`?
10. **Monitoring**: Should this be monitored in Uptime-Kuma? Dashboard tile in Homarr?

## 1) Compose Templates

### Standard Service Template

```yaml
servicename:
  image: vendor/image:latest
  container_name: servicename
  restart: unless-stopped
  ports:
    - "PORT:PORT"
  environment:
    - PUID=${PUID}
    - PGID=${PGID}
    - TZ=${TZ}
    # Add service-specific env vars
  volumes:
    - ./servicename/config:/config
    # Add other volume mounts
```

### VPN-Routed Service Template

For services that should route through VPN (like torrent clients):

```yaml
servicename:
  image: vendor/image:latest
  container_name: servicename
  restart: unless-stopped
  network_mode: "service:gluetun"
  depends_on: [ gluetun ]
  environment:
    - PUID=${PUID}
    - PGID=${PGID}
    - TZ=${TZ}
    # Add service-specific env vars
  volumes:
    - ./servicename/config:/config
    # Add other volume mounts

# AND update gluetun ports section:
gluetun:
  ports:
    - "8080:8080"    # existing qBittorrent
    - "PORT:PORT"    # new service port
```

## 2) Folders & Bring-up

1. **Create service directory**:
   ```bash
   mkdir -p ~/docker/servicename/config
   ```

2. **Add service to docker-compose.yml** using appropriate template above

3. **Bring up the service**:
   ```bash
   cd ~/docker
   docker compose up -d servicename
   ```

4. **Test local access**:
   ```bash
   curl -I http://127.0.0.1:PORT
   docker compose logs servicename
   ```

## 3) Ingress & DNS

1. **Add to cloudflared config** (`docker/cloudflared/config.yml`):
   ```yaml
   - hostname: servicename.rolandgeorge.me
     service: http://127.0.0.1:PORT
   ```

   For HTTPS origins, add:
   ```yaml
   - hostname: servicename.rolandgeorge.me
     service: https://127.0.0.1:PORT
     originRequest:
       noTLSVerify: true
   ```

2. **Restart tunnel to reload config**:
   ```bash
   cd ~/docker
   docker compose restart cloudflared
   ```

3. **Register DNS route** (from cloudflared directory):
   ```bash
   cd ~/docker/cloudflared
   sudo docker run --rm -u root -v "$(pwd)":/root/.cloudflared \
     cloudflare/cloudflared:latest tunnel route dns <TUNNEL_NAME> servicename.rolandgeorge.me
   ```

## 4) Testing

1. **Container status**:
   ```bash
   docker ps | grep servicename
   ```

2. **Local connectivity**:
   ```bash
   curl -I http://127.0.0.1:PORT
   ```

3. **Cloudflared ingress**:
   ```bash
   docker compose logs cloudflared | grep -i "route propagating"
   ```
   Should show: `Route propagating, it may take up to 1 minute for new route to become available`

4. **DNS resolution**:
   ```bash
   nslookup servicename.rolandgeorge.me
   ```
   Should return Cloudflare edge IPs (104.21.x.x, 172.67.x.x, etc.)

5. **Browser test**:
   ```
   https://servicename.rolandgeorge.me
   ```

## 5) Rollback Procedure

If something goes wrong:

1. **Remove container**:
   ```bash
   docker rm -f servicename
   ```

2. **Remove from docker-compose.yml** (delete service block)

3. **Remove ingress** from `cloudflared/config.yml`

4. **Restart tunnel**:
   ```bash
   docker compose restart cloudflared
   ```

5. **Remove DNS route** (optional):
   ```bash
   cd ~/docker/cloudflared
   sudo docker run --rm -u root -v "$(pwd)":/root/.cloudflared \
     cloudflare/cloudflared:latest tunnel route dns <TUNNEL_NAME> servicename.rolandgeorge.me --delete
   ```

## 6) Monitoring Integration

1. **Add Uptime-Kuma monitor**:
   - Monitor type: HTTP(s)
   - URL: `https://servicename.rolandgeorge.me`
   - Interval: 60 seconds
   - Retry: 1

2. **Add Homarr dashboard tile**:
   - Service: Custom
   - URL: `https://servicename.rolandgeorge.me`
   - Icon: Choose appropriate icon
   - Category: Assign to logical group

## 7) Common Issues & Fixes

### Error 1033 (DNS points to tunnel with no live route)
- **Cause**: UUID mismatch, missing ingress, or wrong DNS CNAME target
- **Fix**: 
  - Ensure cloudflared is running with same UUID as DNS CNAME target
  - Verify hostname exists in ingress section
  - Restart cloudflared: `docker compose restart cloudflared`
  - Re-run DNS route command from creds folder

### Error 502 Bad Gateway
- **Cause 1**: Service not listening/published on host
  - **Fix**: Verify service is running and port is published
  - **Test**: `curl http://127.0.0.1:PORT`

- **Cause 2**: Using VPN namespace but not exposing port on gluetun
  - **Fix**: Add port mapping to gluetun service, not the app service

- **Cause 3**: HTTPS origin without TLS verification disabled
  - **Fix**: Add to ingress:
    ```yaml
    originRequest:
      noTLSVerify: true
    ```

### Cloudflared Permission Denied Reading JSON
- **Cause**: Wrong file ownership for tunnel credentials
- **Fix**: 
  ```bash
  sudo chown -R 65532:65532 ~/docker/cloudflared
  sudo chmod 640 ~/docker/cloudflared/*.json
  sudo chmod 644 ~/docker/cloudflared/config.yml ~/docker/cloudflared/cert.pem
  ```

### Service Won't Start (Permission Issues)
- **Cause**: Wrong PUID/PGID or volume permissions
- **Fix**: 
  ```bash
  sudo chown -R $USER:$USER ~/docker/servicename
  ```
  Or check PUID/PGID values in `.env`

### VPN Service Can't Access Internet
- **Cause**: Gluetun VPN connection failed
- **Fix**: 
  ```bash
  docker compose logs gluetun
  # Check VPN credentials and server availability
  ```

## Post-Deployment Checklist

- [ ] Service accessible locally on expected port
- [ ] Container shows as healthy in `docker ps`
- [ ] Cloudflared logs show route propagation
- [ ] DNS resolves to Cloudflare edge IPs
- [ ] Service accessible via subdomain URL
- [ ] Uptime-Kuma monitor configured
- [ ] Homarr dashboard tile added
- [ ] Backup script updated if needed
- [ ] Documentation updated in `homelab_stack.md`
- [ ] Changes committed to git with descriptive message
