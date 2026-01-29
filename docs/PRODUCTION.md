# Production Deployment Guide

Complete guide for deploying Clawdbot to production on VPS/cloud platforms.

## 🎯 Pre-Deployment Checklist

### Infrastructure

- [ ] VPS/Cloud instance provisioned (2GB+ RAM, 20GB+ disk)
- [ ] Domain name configured (optional, but recommended)
- [ ] SSH key-based authentication set up
- [ ] Firewall configured
- [ ] Monitoring/alerting set up

### Secrets Ready

- [ ] Anthropic API key
- [ ] Telegram bot token (from @BotFather)
- [ ] LiteLLM master key (generated)
- [ ] Gateway auth token (generated)
- [ ] Optional: OpenAI, GitHub, Brave Search keys

### Configuration

- [ ] `.env` file prepared
- [ ] Clawdbot config reviewed
- [ ] Reverse proxy config ready (if using)
- [ ] TLS/SSL certificates obtained (if custom domain)

## 🚀 Deployment Steps

### 1. Provision Server

#### DigitalOcean

```bash
# Create droplet via CLI
doctl compute droplet create clawdbot \
  --region sgp1 \
  --size s-2vcpu-2gb \
  --image ubuntu-22-04-x64 \
  --ssh-keys YOUR_SSH_KEY_ID

# Or use web UI:
# - Choose Ubuntu 22.04
# - Select 2GB RAM minimum
# - Choose region close to you
# - Add SSH key
```

#### AWS EC2

```bash
# Create instance
aws ec2 run-instances \
  --image-id ami-xxxxxx \  # Ubuntu 22.04 AMI
  --instance-type t3.small \
  --key-name YOUR_KEY \
  --security-group-ids sg-xxxxxx
```

#### GCP Compute Engine

```bash
gcloud compute instances create clawdbot \
  --machine-type=e2-small \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud
```

### 2. Initial Server Setup

```bash
# SSH into server
ssh root@YOUR_SERVER_IP

# Update system
apt update && apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com | sh

# Install Docker Compose
apt install docker-compose-plugin -y

# Create non-root user (recommended)
adduser clawdbot
usermod -aG docker clawdbot
usermod -aG sudo clawdbot

# Switch to new user
su - clawdbot
```

### 3. Deploy Clawdbot

```bash
# Clone repository
git clone https://github.com/YOUR_USERNAME/clawdbot-docker-deploy.git
cd clawdbot-docker-deploy

# Configure environment
cp .env.example .env
nano .env  # Add your secrets

# Deploy
chmod +x deploy.sh
./deploy.sh
```

### 4. Configure Clawdbot

```bash
# Run configuration wizard
docker exec -it clawdbot-gateway clawdbot configure

# Follow prompts to:
# - Set workspace directory
# - Configure Telegram bot
# - Set up models
# - Enable tools
```

### 5. Set Up Reverse Proxy (Optional)

#### Option A: Caddy (Easiest)

```bash
# Create Caddyfile
cat > Caddyfile << 'EOF'
your-domain.com {
    reverse_proxy localhost:18789
}
EOF

# Run Caddy
docker run -d \
  --name caddy \
  --restart unless-stopped \
  --network host \
  -v $(pwd)/Caddyfile:/etc/caddy/Caddyfile \
  -v caddy_data:/data \
  caddy:latest
```

#### Option B: Nginx

```bash
# Install nginx
apt install nginx certbot python3-certbot-nginx -y

# Create nginx config
cat > /etc/nginx/sites-available/clawdbot << 'EOF'
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://localhost:18789;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
EOF

# Enable site
ln -s /etc/nginx/sites-available/clawdbot /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx

# Get SSL certificate
certbot --nginx -d your-domain.com
```

### 6. Configure Firewall

```bash
# UFW (Ubuntu/Debian)
ufw allow ssh
ufw allow http
ufw allow https
ufw enable
ufw status
```

### 7. Verify Deployment

```bash
# Check container status
docker compose ps

# Check logs
docker compose logs --tail 50

# Test health endpoint
curl http://localhost:18789/health

# Test gateway (from local machine)
curl https://your-domain.com/health
```

## 📊 Monitoring

### Basic Health Checks

```bash
# Create health check script
cat > /home/clawdbot/health-check.sh << 'EOF'
#!/bin/bash
if ! curl -sf http://localhost:18789/health > /dev/null; then
    echo "Clawdbot health check failed!"
    docker compose -f /home/clawdbot/clawdbot-docker-deploy/docker-compose.yml restart
fi
EOF

chmod +x /home/clawdbot/health-check.sh

# Add to crontab
crontab -e
# Add: */5 * * * * /home/clawdbot/health-check.sh
```

### UptimeRobot

1. Sign up at https://uptimerobot.com
2. Add monitor:
   - Type: HTTP(s)
   - URL: `https://your-domain.com/health`
   - Interval: 5 minutes

### Prometheus + Grafana (Advanced)

```yaml
# Add to docker-compose.yml
  prometheus:
    image: prom/prometheus
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
    ports:
      - "9090:9090"

  grafana:
    image: grafana/grafana
    ports:
      - "3000:3000"
    volumes:
      - grafana_data:/var/lib/grafana
```

## 🔄 Backup Strategy

### Automated Backups

```bash
# Create backup script
cat > /home/clawdbot/backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/home/clawdbot/backups"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

# Backup Docker volumes
docker run --rm \
  -v clawdbot-docker-deploy_clawdbot-data:/data \
  -v "$BACKUP_DIR":/backup \
  alpine tar czf "/backup/clawdbot-data-$DATE.tar.gz" /data

# Backup .env
cp /home/clawdbot/clawdbot-docker-deploy/.env "$BACKUP_DIR/.env-$DATE"

# Keep only last 7 days
find "$BACKUP_DIR" -name "clawdbot-*.tar.gz" -mtime +7 -delete
find "$BACKUP_DIR" -name ".env-*" -mtime +7 -delete

echo "Backup completed: $DATE"
EOF

chmod +x /home/clawdbot/backup.sh

# Schedule daily backups
crontab -e
# Add: 0 2 * * * /home/clawdbot/backup.sh
```

### Off-Site Backups

```bash
# Install rclone
curl https://rclone.org/install.sh | bash

# Configure cloud storage (S3, B2, GCS, etc.)
rclone config

# Add to backup script
rclone sync /home/clawdbot/backups remote:clawdbot-backups
```

## 🔧 Maintenance

### Update Procedure

```bash
# 1. Backup first
/home/clawdbot/backup.sh

# 2. Pull latest changes
cd /home/clawdbot/clawdbot-docker-deploy
git pull

# 3. Update Docker images
docker compose pull

# 4. Restart with new images
docker compose up -d

# 5. Verify
docker compose ps
docker compose logs --tail 50
```

### Log Rotation

```bash
# Configure Docker logging
# Edit docker-compose.yml:
logging:
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "5"
```

### Resource Monitoring

```bash
# Install htop
apt install htop -y

# Monitor in real-time
htop

# Check Docker stats
docker stats

# Check disk usage
df -h
docker system df
```

## 🚨 Troubleshooting

### Container Won't Start

```bash
# Check logs
docker compose logs

# Check disk space
df -h

# Check memory
free -h

# Restart Docker daemon
systemctl restart docker
```

### High Memory Usage

```bash
# Check container stats
docker stats

# Set memory limits in docker-compose.yml
deploy:
  resources:
    limits:
      memory: 2G
```

### Connection Issues

```bash
# Check if port is listening
netstat -tulpn | grep 18789

# Check firewall
ufw status
iptables -L

# Test from server
curl http://localhost:18789/health

# Check reverse proxy
nginx -t
systemctl status nginx
```

## 📈 Scaling

### Vertical Scaling

Upgrade server resources:

```bash
# DigitalOcean
doctl compute droplet-action resize DROPLET_ID --size s-4vcpu-8gb

# AWS
aws ec2 modify-instance-attribute --instance-id i-xxxxx --instance-type t3.large
```

### Horizontal Scaling (Advanced)

For high availability, deploy multiple instances behind a load balancer.

## 📚 Additional Resources

- [Docker Production Best Practices](https://docs.docker.com/config/containers/resource_constraints/)
- [Nginx Configuration](https://nginx.org/en/docs/)
- [Let's Encrypt](https://letsencrypt.org/getting-started/)
- [Caddy Documentation](https://caddyserver.com/docs/)

## 🆘 Support

- GitHub Issues: https://github.com/YOUR_USERNAME/clawdbot-docker-deploy/issues
- Clawdbot Docs: https://docs.clawd.bot
- Community: https://discord.com/invite/clawd
