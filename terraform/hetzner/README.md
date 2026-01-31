# Hetzner Terraform (Clawdbot / Moltbot Telegram Bot)

This folder provisions a Hetzner VPS + bootstraps a **single Telegram bot** running Moltbot Gateway in Docker.

## What it does

- Creates a Hetzner VM
- Installs Docker + docker compose plugin
- Creates persistent host dirs:
  - `/root/.clawdbot`
  - `/root/clawd`
- Clones your deploy repo
- Writes `.env`
- Runs `docker compose -f docker-compose.vps.yml up -d`
- Exposes the Control UI via **HTTPS only** using Caddy + Let's Encrypt
- Inbound firewall allows **80/443 only** (no SSH)

## Prereqs

- Hetzner Cloud account + API token
- A registered SSH key in Hetzner Cloud
- Terraform installed locally

## Usage

```bash
cd terraform/hetzner
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars
terraform init
terraform apply
```

After apply, SSH in:
```bash
ssh root@<server_ip>
cd /opt/clawdbot-docker-deploy
docker compose ps
```

Control UI (from your laptop):
```bash
ssh -N -L 18789:127.0.0.1:18789 root@<server_ip>
```

Open:
- http://127.0.0.1:18789/
- Paste the gateway token (or open the tokenized URL).

## Notes

- Direct Anthropic mode is supported (set `anthropic_api_key`).
- LiteLLM mode is also supported (set `litellm_base_url` + `litellm_api_key`).

