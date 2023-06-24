provider "digitalocean" {
  token = var.digitalocean_api_token
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}