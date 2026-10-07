module "fullstack" {
  for_each = var.fullstack_apps

  source = "./modules/fullstack"

  fullstack_app = each.value
  zone_name     = var.zone_name
  zone_id       = try(data.cloudflare_zone.this["default"].id, null)

  providers = {
    auth0      = auth0
    azurerm    = azurerm
    cloudflare = cloudflare
    random     = random
    supabase   = supabase
    time       = time
  }
}
