data "auth0_tenant" "this" {}

resource "auth0_client" "this" {
  count = var.fullstack_app.auth ? 1 : 0

  name     = "spa-${var.fullstack_app.project_name}"
  app_type = "spa"

  callbacks = [
    local.has_custom_domain
    ? "https://${var.fullstack_app.custom_domain}.${var.zone_name}"
    : "https://${azurerm_static_web_app.this[0].default_host_name}",
    "https://*.app.github.dev" # GitHub codespace debugging
  ]
  allowed_logout_urls = [
    local.has_custom_domain
    ? "https://${var.fullstack_app.custom_domain}.${var.zone_name}"
    : "https://${azurerm_static_web_app.this[0].default_host_name}",
    "https://*.app.github.dev" # GitHub codespace debugging
  ]
  allowed_origins = [
    local.has_custom_domain
    ? "https://${var.fullstack_app.custom_domain}.${var.zone_name}"
    : "https://${azurerm_static_web_app.this[0].default_host_name}",
    "https://*.app.github.dev" # GitHub codespace debugging
  ]
  web_origins = [
    local.has_custom_domain
    ? "https://${var.fullstack_app.custom_domain}.${var.zone_name}"
    : "https://${azurerm_static_web_app.this[0].default_host_name}",
    "https://*.app.github.dev" # GitHub codespace debugging
  ]

  jwt_configuration {
    alg = "RS256"
  }
}
