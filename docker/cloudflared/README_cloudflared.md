# Cloudflared Setup Guide

## Local-config vs Token Mode

This configuration uses **local-config mode** where we manage credentials and configuration files manually, rather than using the simpler token mode. This gives us more control over the tunnel configuration and ingress rules.

## Credentials Location

The following files must be placed in this directory (`docker/cloudflared/`):
- `cert.pem` - Your Cloudflare account certificate
- `<UUID>.json` - Your tunnel credentials file
- `config.yml` - Tunnel configuration (already provided)

These files are mapped to `/etc/cloudflared/` inside the container.

## Creating Credentials

Run these commands from the `docker/cloudflared` directory:

```bash
cd ~/docker/cloudflared

# Login and get cert.pem
sudo docker run --rm -u root -v "$(pwd)":/root/.cloudflared cloudflare/cloudflared:latest tunnel login

# Create a new tunnel (choose this if creating for the first time)
sudo docker run --rm -u root -v "$(pwd)":/root/.cloudflared cloudflare/cloudflared:latest tunnel create sol-local

# OR if the tunnel already exists:
sudo docker run --rm -u root -v "$(pwd)":/root/.cloudflared cloudflare/cloudflared:latest tunnel list
sudo docker run --rm -u root -v "$(pwd)":/root/.cloudflared cloudflare/cloudflared:latest tunnel download <TUNNEL_UUID>
```

## Register DNS Routes

Run this from the `docker/cloudflared` directory using your tunnel NAME (not UUID):

```bash
for host in plex sonarr radarr n8n qbit portainer dash prowlarr bazarr overseerr tautulli glances status logs dns; do
  sudo docker run --rm -u root -v "$(pwd)":/root/.cloudflared cloudflare/cloudflared:latest \
    tunnel route dns <TUNNEL_NAME> "${host}.rolandgeorge.me"
done
```

## Permissions Fix

If cloudflared logs show "permission denied" reading JSON files, fix ownership to uid 65532:

```bash
sudo chown -R 65532:65532 ~/docker/cloudflared
sudo chmod 640 ~/docker/cloudflared/*.json
sudo chmod 644 ~/docker/cloudflared/config.yml ~/docker/cloudflared/cert.pem
```

## Configuration Notes

- The tunnel runs in host networking mode to reach services on 127.0.0.1
- All ingress routes point to local HTTP endpoints
- Replace `<TUNNEL_UUID>` in both `config.yml` and `docker-compose.yml` with your actual tunnel UUID
- Replace `<TUNNEL_NAME>` in DNS registration commands with your actual tunnel name
