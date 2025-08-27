# Quick Security Setup Guide

## 🚨 **Immediate Security Actions Required**

This guide provides the essential security setup steps that should be completed immediately after deploying the SOL Homelab stack.

## 1. **Generate Secure Passwords (5 minutes)**

```bash
# From the project root directory
make setup-passwords
```

This will:
- ✅ Generate secure passwords for n8n, Grafana, and backup encryption
- ✅ Create/update your `.env` file
- ✅ Set proper file permissions for backup encryption

**Output Example:**
```
[SUCCESS] All passwords generated and updated in .env file
Password Summary:
==================
n8n User: admin
n8n Password: K8mN9pQ2rS5tU7vW1xY3zA4bC6dE8f
Grafana Admin Password: H2jK4lM6nO8pQ0rS2tU4vW6xY8zA0b
Backup Encryption: Generated
```

## 2. **Validate Security Configuration (2 minutes)**

```bash
make validate
```

This will:
- ✅ Check for port conflicts
- ✅ Verify security constraints are in place
- ✅ Validate environment variables
- ✅ Confirm all services have proper security settings

**Expected Output:**
```
[SUCCESS] No port conflicts detected
[SUCCESS] Environment variables configured
[SUCCESS] All services have security constraints configured
[SUCCESS] Validation completed successfully!
```

## 3. **Test Critical Services (5 minutes)**

### Test n8n Authentication
```bash
# Try to access n8n without credentials (should fail)
curl -I http://127.0.0.1:5678

# Should return 401 Unauthorized
```

### Test Grafana Authentication
```bash
# Try to access Grafana without credentials (should fail)
curl -I http://127.0.0.1:3000

# Should return 401 Unauthorized
```

## 4. **Verify Backup Security (3 minutes)**

```bash
# Check backup encryption password exists
ls -la .backup_password

# Should show: -rw------- (600 permissions)
# File should exist and be readable only by owner
```

## 5. **Check Port Security (2 minutes)**

```bash
# Verify no unnecessary ports are exposed
netstat -tlnp | grep LISTEN

# Should only show expected ports:
# - 32400 (Plex)
# - 8989 (Sonarr)
# - 7878 (Radarr)
# - 5678 (n8n)
# - 8080 (qBittorrent via gluetun)
# - 9000/9443 (Portainer)
# - 7575 (Homarr)
# - 9696 (Prowlarr)
# - 6767 (Bazarr)
# - 5055 (Overseerr)
# - 8181 (Tautulli)
# - 61208 (Glances)
# - 3001 (Uptime-Kuma)
# - 9999 (Dozzle)
# - 3000 (AdGuard Home)
# - 8081 (cAdvisor)
```

## 🔒 **Security Checklist**

- [ ] **Passwords Generated**: `make setup-passwords` completed
- [ ] **Configuration Validated**: `make validate` passed
- [ ] **Authentication Working**: n8n and Grafana require credentials
- [ ] **Backup Encrypted**: `.backup_password` file exists with 600 permissions
- [ ] **Ports Secure**: Only expected ports are listening
- [ ] **Services Running**: All containers show as healthy

## 🚨 **If Something Goes Wrong**

### Password Generation Fails
```bash
# Check if openssl is available
which openssl

# Install if missing (Ubuntu/Debian)
sudo apt update && sudo apt install openssl

# Try again
make setup-passwords
```

### Validation Fails
```bash
# Check specific error
make validate

# Common fixes:
# - Ensure .env file exists
# - Check Docker Compose syntax
# - Verify no port conflicts
```

### Authentication Not Working
```bash
# Check environment variables
grep -E "N8N_PASSWORD|GRAFANA_ADMIN_PASSWORD" docker/.env

# Restart services after password changes
cd docker && docker compose restart n8n grafana
```

## 📋 **Next Security Steps**

After completing this quick setup:

1. **Review Security Documentation**: Read `docs/security_best_practices.md`
2. **Set Up Monitoring**: Configure Uptime-Kuma alerts
3. **Regular Updates**: Enable Watchtower notifications
4. **Backup Testing**: Test backup restoration process
5. **Access Review**: Review who has access to services

## 🔍 **Security Monitoring**

### Daily Checks
- Service health status
- Unusual access patterns
- Resource usage anomalies

### Weekly Checks
- Container updates available
- Log analysis for errors
- Backup verification

### Monthly Checks
- Password rotation
- Security policy review
- Access control audit

---

**Time to Complete**: ~15 minutes  
**Security Level**: Production Ready  
**Next Review**: Weekly
