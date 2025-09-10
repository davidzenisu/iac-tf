resource "azurerm_resource_group" "static_web_app" {
  for_each = var.static_web_apps

  name     = each.value.resource_group_name
  location = each.value.location
}

module "static_web_app" {
  for_each = var.static_web_apps

  source  = "Azure/avm-res-web-staticsite/azurerm"
  version = "~> 0.6.2"

  name                = each.value.name
  location            = azurerm_resource_group.static_web_app[each.key].location
  resource_group_name = azurerm_resource_group.static_web_app[each.key].name
  app_settings = {

  }

  enable_telemetry = false
}

resource "cloudflare_record" "static_web_app" {
  for_each = var.static_web_apps

  zone_id = data.cloudflare_zone.this["default"].id
  name    = each.value.custom_domain
  content = module.static_web_app[each.key].resource_uri
  type    = "CNAME"
  proxied = false
}

resource "time_sleep" "static_web_app_custom_domain_wait" {
  count = length(
    [for v in var.static_web_apps : v if v.custom_domain != null]
  ) != 0 ? 1 : 0

  create_duration  = "300s"
  destroy_duration = "0s"

  depends_on = [
    cloudflare_record.static_web_app,
  ]
}

# can't be created via module because it's evaluated immediately!
resource "azurerm_static_web_app_custom_domain" "static_web_app" {
  for_each = {
    for k, v in var.static_web_apps : k => v if v.custom_domain != null
  }

  static_web_app_id = module.static_web_app[each.key].resource_id
  domain_name       = "${each.value.custom_domain}.${var.zone_name}"
  validation_type   = "cname-delegation"

  depends_on = [
    cloudflare_record.static_web_app,
    time_sleep.static_web_app_custom_domain_wait,
  ]
}
