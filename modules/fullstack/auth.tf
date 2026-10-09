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

resource "auth0_resource_server" "this" {
  count = var.fullstack_app.auth && var.fullstack_app.backend ? 1 : 0

  name                 = "${var.fullstack_app.project_name} API"
  identifier           = local.api_audience
  signing_alg          = "RS256"
  token_lifetime       = 3600
  token_dialect        = "access_token_authz"
  enforce_policies     = true
  allow_offline_access = false
}

resource "auth0_resource_server_scope" "read_api" {
  count = var.fullstack_app.auth && var.fullstack_app.backend ? 1 : 0

  resource_server_identifier = auth0_resource_server.this[0].identifier
  scope                      = "read:api"
  description                = "Access the ${var.fullstack_app.project_name} API."
}

resource "auth0_role_permission" "user_read_api" {
  count = var.fullstack_app.auth && var.fullstack_app.backend ? 1 : 0

  role_id                    = var.auth0_user_role_id
  resource_server_identifier = auth0_resource_server.this[0].identifier
  permission                 = auth0_resource_server_scope.read_api[0].scope
}

resource "auth0_client_grant" "frontend_api" {
  count = var.fullstack_app.auth && var.fullstack_app.backend ? 1 : 0

  client_id = auth0_client.this[0].id
  audience  = auth0_resource_server.this[0].identifier
  scopes    = [auth0_resource_server_scope.read_api[0].scope]
}
