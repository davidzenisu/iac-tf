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

  custom_domains = each.value.custom_domain == null ? {} : {
    default = {
      domain_name     = each.value.custom_domain
      validation_type = "cname-delegation"

      create_cname_records = false
      create_txt_records   = false
    }
  }

  enable_telemetry = false
}

resource "cloudflare_record" "static_web_app" {
  for_each = var.static_web_apps

  zone_id = data.cloudflare_zone.this["default"].id
  name    = "grades"
  content = module.static_web_app[each.key].resource_uri
  type    = "CNAME"
  proxied = false
}

