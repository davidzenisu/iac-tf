resource "azurerm_resource_group" "static_web_app" {
  for_each = var.static_web_apps

  name     = each.value.resource_group_name
  location = each.value.location
}

module "staticsite" {
  for_each = var.static_web_apps

  source  = "Azure/avm-res-web-staticsite/azurerm"
  version = "~> 0.6.2"

  name                = each.value.name
  location            = azurerm_resource_group.static_web_app[each.key].location
  resource_group_name = azurerm_resource_group.static_web_app[each.key].name
  app_settings = {

  }

  custom_domains   = each.value.custom_domains
  enable_telemetry = false
}
