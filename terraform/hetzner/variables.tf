variable "hcloud_token" {
  type      = string
  sensitive = true
}

variable "ssh_key_name" {
  type        = string
  description = "Name of an SSH key already uploaded to Hetzner Cloud"
}

variable "server_name" {
  type    = string
  default = "clawdbot-bot"
}

variable "image" {
  type    = string
  default = "ubuntu-24.04"
}

variable "server_type" {
  type    = string
  default = "cx22"
}

variable "location" {
  type    = string
  default = "sgp1"
}

variable "domain" {
  type        = string
  description = "Public hostname for this bot, e.g. cust-123.mydomain.com"
}

variable "caddy_email" {
  type        = string
  description = "Email for Let's Encrypt (Caddy)."
}

variable "repo_url" {
  type        = string
  description = "Git URL of your clawdbot-docker-deploy repo (must be reachable from VPS)."
}

variable "repo_branch" {
  type    = string
  default = "main"
}

variable "gateway_port" {
  type    = number
  default = 18789
}

variable "gateway_auth_token" {
  type      = string
  sensitive = true
}

variable "telegram_bot_token" {
  type      = string
  sensitive = true
}

variable "telegram_allow_from" {
  type        = string
  description = "JSON array string of allowed Telegram user IDs, e.g. [\"145...\"]"
}

variable "anthropic_api_key" {
  type      = string
  sensitive = true
  default   = ""
}

variable "litellm_base_url" {
  type    = string
  default = ""
}

variable "litellm_api_key" {
  type      = string
  sensitive = true
  default   = ""
}

variable "brave_api_key" {
  type      = string
  sensitive = true
  default   = ""
}
