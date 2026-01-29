# Security Best Practices

This document outlines security considerations for deploying Clawdbot in production.

## 🔐 Secrets Management

### Environment Variables

**✅ DO:**
- Store all secrets in `.env` file
- Use strong, randomly generated keys
- Set `.env` permissions to `600` (owner read/write only)
- Never commit `.env` to version control
- Use different secrets for dev/staging/prod

**❌ DON'T:**
- Hardcode secrets in source code
- Share secrets via chat/email
- Use weak or default passwords
- Reuse secrets across environments

### Generating Secure Keys

```bash
# Gateway auth token (48 characters)
openssl rand -hex 24

# LiteLLM master key (64 characters)
openssl rand -hex 32

# UUID-based secrets
uuidgen
```

## 🛡️ Sandbox Security

### Docker Sandbox Configuration

The deployment uses Docker-in-Docker sandboxing for command execution:

```json
{
  "agents": {
    "defaults": {
      "sandbox": {
        "mode": "all",
        "workspaceAccess": "rw",
        "docker": {
          "network": "bridge",
          "readOnlyRoot": true,
          "capDrop": ["ALL"],
          "capAdd": ["NET_BIND_SERVICE"],
          "pidsLimit": 100,
          "memory": "512m",
          "cpus": "1.0"
        }
      }
    }
  }
}
```

### Resource Limits

Always set resource limits to prevent DoS:

```yaml
deploy:
  resources:
    limits:
      cpus: '2'
      memory: 4G
    reservations:
      memory: 512M
```

## 🌐 Network Security

### Firewall Rules

**Minimum required ports:**
- `22/tcp` - SSH (restricted to your IP)
- `80/tcp` - HTTP (if using reverse proxy)
- `443/tcp` - HTTPS (if using reverse proxy)

**Block everything else:**

```bash
# UFW (Ubuntu/Debian)
ufw default deny incoming
ufw default allow outgoing
ufw allow from YOUR_IP to any port 22
ufw allow 80/tcp
ufw allow 443/tcp
ufw enable

# firewalld (CentOS/RHEL)
firewall-cmd --permanent --remove-service=dhcpv6-client
firewall-cmd --permanent --add-service=ssh
firewall-cmd --permanent --add-source=YOUR_IP
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --reload
```

### Gateway Binding

**Default (localhost only):**
```yaml
ports:
  - "127.0.0.1:18789:18789"  # ✅ Safe - localhost only
```

**Public binding (with reverse proxy):**
```yaml
ports:
  - "18789:18789"  # ⚠️ Only with firewall + auth
```

## 🔒 TLS/SSL

### Using Caddy (Recommended)

Automatic HTTPS with Let's Encrypt:

```bash
# Install Caddy
docker run -d \
  --name caddy \
  --restart unless-stopped \
  -p 80:80 \
  -p 443:443 \
  -v caddy_data:/data \
  -v caddy_config:/config \
  -v $(pwd)/Caddyfile:/etc/caddy/Caddyfile \
  caddy:latest
```

**Caddyfile:**
```
your-domain.com {
    reverse_proxy clawdbot-gateway:18789
}
```

### Using Let's Encrypt + Nginx

```bash
# Install certbot
apt install certbot python3-certbot-nginx

# Obtain certificate
certbot --nginx -d your-domain.com

# Auto-renewal
certbot renew --dry-run
```

## 👥 Access Control

### Telegram Channel Security

```json
{
  "channels": {
    "telegram": {
      "dmPolicy": "pairing",
      "groupPolicy": "allowlist",
      "allowFrom": [1459204134],
      "groupAllowFrom": [-1001234567890]
    }
  }
}
```

### Tool Restrictions

```json
{
  "tools": {
    "exec": {
      "security": "allowlist",
      "safeBins": ["git", "gh", "npm"]
    },
    "elevated": {
      "enabled": false
    }
  }
}
```

## 📊 Audit Logging

### Enable Command Logging

```json
{
  "hooks": {
    "internal": {
      "entries": {
        "command-logger": {
          "enabled": true
        }
      }
    }
  }
}
```

### Log Rotation

```bash
# Docker logging driver
docker run \
  --log-driver=json-file \
  --log-opt max-size=10m \
  --log-opt max-file=3 \
  ...
```

Or in `docker-compose.yml`:
```yaml
logging:
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"
```

## 🔄 Regular Maintenance

### Security Checklist

**Weekly:**
- [ ] Review logs for suspicious activity
- [ ] Check for failed login attempts
- [ ] Monitor resource usage

**Monthly:**
- [ ] Update Docker images
- [ ] Update Clawdbot to latest version
- [ ] Review and rotate API keys if needed
- [ ] Review access control lists

**Quarterly:**
- [ ] Full security audit
- [ ] Penetration testing
- [ ] Review and update firewall rules

### Update Process

```bash
# 1. Backup data
docker run --rm \
  -v clawdbot-docker-deploy_clawdbot-data:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/backup-$(date +%Y%m%d).tar.gz /data

# 2. Pull latest images
docker compose pull

# 3. Restart with new images
docker compose up -d

# 4. Verify health
docker compose ps
docker compose logs --tail 50
```

## 🚨 Incident Response

### Compromise Indicators

Watch for:
- Unexpected API calls
- Unusual resource spikes
- Failed authentication attempts
- Modified config files
- Unknown containers/processes

### Response Steps

1. **Isolate:**
   ```bash
   docker compose down
   iptables -A INPUT -j DROP  # Block all incoming
   ```

2. **Investigate:**
   ```bash
   docker compose logs > incident-$(date +%Y%m%d).log
   ```

3. **Rotate all secrets:**
   - API keys
   - Bot tokens
   - Gateway tokens

4. **Restore from backup if needed**

5. **Update and redeploy**

## 📞 Security Contacts

- **Security issues:** security@example.com
- **Clawdbot security:** https://github.com/clawdbot/clawdbot/security

## 📚 References

- [OWASP Docker Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)
- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
