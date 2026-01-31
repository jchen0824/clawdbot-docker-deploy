terraform {
  required_version = ">= 1.5.0"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = ">= 1.48.0"
    }
  }
}

provider "hcloud" {
  token = var.hcloud_token
}

resource "hcloud_server" "bot" {
  name        = var.server_name
  image       = var.image
  server_type = var.server_type
  location    = var.location

  ssh_keys = [var.ssh_key_name]

  user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    repo_url            = var.repo_url
    repo_branch         = var.repo_branch
    gateway_port        = var.gateway_port
    gateway_auth_token  = var.gateway_auth_token
    telegram_bot_token  = var.telegram_bot_token
    telegram_allow_from = var.telegram_allow_from
    anthropic_api_key   = var.anthropic_api_key
    litellm_base_url    = var.litellm_base_url
    litellm_api_key     = var.litellm_api_key
    brave_api_key       = var.brave_api_key
    domain              = var.domain
    caddy_email         = var.caddy_email
  })

  firewall_ids = [hcloud_firewall.web_only.id]
}

resource "hcloud_firewall" "web_only" {
  name = "${var.server_name}-web-only"

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "80"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "443"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
}

output "server_ip" {
  value = hcloud_server.bot.ipv4_address
}
