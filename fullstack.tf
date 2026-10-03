module "fullstack" {
  source = "./modules/fullstack"

  fullstack_apps = var.fullstack_apps
  zone_name      = var.zone_name
  zone_id        = try(data.cloudflare_zone.this["default"].id, null)

  providers = {
    auth0      = auth0
    azurerm    = azurerm
    cloudflare = cloudflare
    random     = random
    supabase   = supabase
    time       = time
  }
}
