resource "auth0_client" "this" {
  for_each = local.auth_apps

  name     = "spa-${each.value.project_name}"
  app_type = "spa"

  callbacks = [
    each.value.custom_domain != null
    ? "https://${each.value.custom_domain}.${var.zone_name}"
    : "https://${azurerm_static_web_app.this[each.key].default_host_name}"
  ]
  allowed_logout_urls = [
    each.value.custom_domain != null
    ? "https://${each.value.custom_domain}.${var.zone_name}"
    : "https://${azurerm_static_web_app.this[each.key].default_host_name}"
  ]
  allowed_origins = [
    each.value.custom_domain != null
    ? "https://${each.value.custom_domain}.${var.zone_name}"
    : "https://${azurerm_static_web_app.this[each.key].default_host_name}"
  ]
  web_origins = [
    each.value.custom_domain != null
    ? "https://${each.value.custom_domain}.${var.zone_name}"
    : "https://${azurerm_static_web_app.this[each.key].default_host_name}"
  ]
}
