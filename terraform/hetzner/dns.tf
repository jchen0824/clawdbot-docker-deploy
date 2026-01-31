# GoDaddy DNS automation (runs locally during terraform apply)
# If godaddy_api_key/secret are not provided, this resource is skipped.

resource "null_resource" "godaddy_dns" {
  count = (var.godaddy_api_key != "" && var.godaddy_api_secret != "") ? 1 : 0

  triggers = {
    ip          = hcloud_server.bot.ipv4_address
    root_domain = var.root_domain
    subdomain   = var.subdomain
    ttl         = tostring(var.godaddy_ttl)
  }

  provisioner "local-exec" {
    command = "GODADDY_API_KEY='${var.godaddy_api_key}' GODADDY_API_SECRET='${var.godaddy_api_secret}' bash ${path.module}/godaddy_dns.sh ${var.root_domain} ${var.subdomain} ${hcloud_server.bot.ipv4_address} ${var.godaddy_ttl}"
  }

  depends_on = [hcloud_server.bot]
}
