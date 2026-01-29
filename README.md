# Clawdbot Docker Deployment 🐳

Production-ready Docker deployment for [Clawdbot](https://github.com/clawdbot/clawdbot) with security best practices.

Deploy Clawdbot to any VPS or cloud machine (DigitalOcean, AWS, GCP, etc.) with a single script.

## 🚀 Quick Start

### Prerequisites

- Docker & Docker Compose installed
- API keys ready:
  - Anthropic API key (required)
  - Telegram bot token (required)
  - Optional: OpenAI, GitHub, Brave Search

### One-Command Deploy

```bash
git clone https://github.com/YOUR_USERNAME/clawdbot-docker-deploy.git
cd clawdbot-docker-deploy
cp .env.example .env
# Edit .env with your API keys
chmod +x deploy.sh
./deploy.sh
```

## 📋 Setup Steps

### 1. Clone Repository

```bash
git clone https://github.com/YOUR_USERNAME/clawdbot-docker-deploy.git
cd clawdbot-docker-deploy
```

### 2. Configure Environment

```bash
cp .env.example .env
nano .env  # or vim, code, etc.
```

**Required variables:**
```env
ANTHROPIC_API_KEY=sk-ant-xxxxx
TELEGRAM_BOT_TOKEN=1234567890:ABCxxx
LITELLM_MASTER_KEY=$(openssl rand -hex 32)
```

**Optional variables:**
```env
OPENAI_API_KEY=sk-proj-xxxxx
GH_TOKEN=ghp_xxxxx
BRAVE_API_KEY=BSAxxx
```

### 3. Deploy

```bash
chmod +x deploy.sh
./deploy.sh
```

### 4. Configure Clawdbot

```bash
docker exec -it clawdbot-gateway clawdbot configure
```

Follow the wizard to:
- Set up your workspace
- Connect Telegram bot
- Configure models and tools

## 🔒 Security Features

### ✅ Built-in Security

- **No hardcoded secrets** - all sensitive data in `.env`
- **Secure file permissions** - `.env` automatically set to `600`
- **Non-root user** - container runs as non-root
- **Read-only Docker socket** - sandbox access without full Docker privileges
- **Network isolation** - dedicated Docker network
- **Health checks** - automatic restart on failure
- **Minimal attack surface** - Alpine Linux base image

### 🛡️ Sandbox Mode

Docker-in-Docker sandbox enabled by default:
- Isolated command execution
- Network restrictions
- Resource limits
- File system isolation

Configuration in `clawdbot.json`:
```json
{
  "agents": {
    "defaults": {
      "sandbox": {
        "mode": "all",
        "docker": {
          "network": "bridge"
        }
      }
    }
  }
}
```

### 🔐 Gateway Security

- **Token authentication** - auto-generated secure token
- **Localhost binding** - not exposed to internet by default
- **TLS ready** - configure with reverse proxy (see below)

## 🌐 External Access (Production)

For production deployments with external access, use a reverse proxy:

### Option A: Nginx

```nginx
server {
    listen 443 ssl http2;
    server_name your-domain.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass http://localhost:18789;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Option B: Caddy (easiest)

```
your-domain.com {
    reverse_proxy localhost:18789
}
```

Caddy handles SSL/TLS automatically with Let's Encrypt.

## 📊 Management Commands

### View Logs

```bash
docker compose logs -f
```

### Restart

```bash
docker compose restart
```

### Stop

```bash
docker compose down
```

### Update Clawdbot

```bash
docker compose pull
docker compose up -d
```

### Access Shell

```bash
docker exec -it clawdbot-gateway sh
```

### Backup Data

```bash
docker run --rm -v clawdbot-docker-deploy_clawdbot-data:/data -v $(pwd):/backup alpine tar czf /backup/clawdbot-backup-$(date +%Y%m%d).tar.gz /data
```

### Restore Data

```bash
docker run --rm -v clawdbot-docker-deploy_clawdbot-data:/data -v $(pwd):/backup alpine tar xzf /backup/clawdbot-backup-YYYYMMDD.tar.gz -C /
```

## 🔧 Configuration

### Edit Config

```bash
docker exec -it clawdbot-gateway clawdbot config edit
```

### Gateway Settings

Edit `docker-compose.yml` to change:
- Ports
- Resource limits
- Environment variables
- Volume mounts

Example resource limits:
```yaml
deploy:
  resources:
    limits:
      cpus: '2'
      memory: 4G
    reservations:
      memory: 512M
```

## 🐛 Troubleshooting

### Container won't start

```bash
docker compose logs clawdbot
```

Check for:
- Missing environment variables
- Invalid API keys
- Port conflicts

### Permission errors

```bash
docker exec -it clawdbot-gateway sh
ls -la /data
```

Ensure volumes have correct permissions.

### Sandbox not working

Check Docker socket access:
```bash
docker exec -it clawdbot-gateway docker ps
```

Should show running containers.

### Gateway unreachable

```bash
docker compose ps
netstat -tulpn | grep 18789
```

Ensure port is listening and not blocked by firewall.

## 📦 What's Included

```
clawdbot-docker-deploy/
├── docker-compose.yml      # Main compose configuration
├── .env.example            # Environment template
├── deploy.sh              # Deployment script
├── README.md              # This file
├── .gitignore             # Git ignore patterns
└── docs/
    ├── SECURITY.md        # Security guide
    └── PRODUCTION.md      # Production deployment guide
```

## 🌍 Cloud Provider Guides

### DigitalOcean Droplet

```bash
# Create droplet (Ubuntu 22.04, 2GB+ RAM)
# SSH into droplet
ssh root@your-droplet-ip

# Install Docker
curl -fsSL https://get.docker.com | sh

# Deploy Clawdbot
git clone https://github.com/YOUR_USERNAME/clawdbot-docker-deploy.git
cd clawdbot-docker-deploy
cp .env.example .env
nano .env  # Add your keys
./deploy.sh
```

### AWS EC2

Same as DigitalOcean, use Amazon Linux 2 or Ubuntu AMI.

### Google Cloud Platform

```bash
# Create Compute Engine instance
# SSH and follow DigitalOcean steps
```

## 📚 Additional Resources

- [Clawdbot Documentation](https://docs.clawd.bot)
- [Docker Documentation](https://docs.docker.com)
- [Telegram Bot API](https://core.telegram.org/bots)
- [Security Best Practices](./docs/SECURITY.md)

## 🤝 Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Test thoroughly
4. Submit a pull request

## 📄 License

MIT License - see LICENSE file

## ⚠️ Security

Found a security issue? Please email security@example.com instead of opening an issue.

## 🙏 Acknowledgments

- [Clawdbot](https://github.com/clawdbot/clawdbot) - The amazing AI assistant framework
- Community contributors

---

**Questions?** Open an issue or check the [discussion forum](https://github.com/clawdbot/clawdbot/discussions)
