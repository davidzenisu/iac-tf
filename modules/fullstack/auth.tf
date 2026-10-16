data "auth0_tenant" "this" {}

resource "auth0_client" "this" {
  count = var.fullstack_app.auth ? 1 : 0

  # Shown on the Auth0 login page ("continue to <name>")
  name     = coalesce(var.fullstack_app.display_name, "spa-${var.fullstack_app.project_name}")
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

# Public client for logging in directly via the FastAPI Swagger UI (/docs)
resource "auth0_client" "docs" {
  count = var.fullstack_app.auth && var.fullstack_app.backend ? 1 : 0

  name        = var.fullstack_app.display_name != null ? "${var.fullstack_app.display_name} API docs" : "docs-${var.fullstack_app.project_name}"
  app_type    = "spa"
  grant_types = ["authorization_code"]

  callbacks = [
    "https://api.${var.fullstack_app.custom_domain}.${var.zone_name}/docs/oauth2-redirect",
    "https://*.app.github.dev/docs/oauth2-redirect" # GitHub codespace debugging
  ]
  allowed_origins = [
    "https://api.${var.fullstack_app.custom_domain}.${var.zone_name}",
    "https://*.app.github.dev" # GitHub codespace debugging
  ]
  web_origins = [
    "https://api.${var.fullstack_app.custom_domain}.${var.zone_name}",
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

resource "auth0_resource_server_scope" "custom_api" {
  for_each = var.fullstack_app.auth && var.fullstack_app.backend ? var.fullstack_app.auth0_permissions : {}

  resource_server_identifier = auth0_resource_server.this[0].identifier
  scope                      = each.key
  description                = each.value.description
}

resource "auth0_role_permission" "user_read_api" {
  count = var.fullstack_app.auth && var.fullstack_app.backend ? 1 : 0

  role_id                    = var.auth0_user_role_id
  resource_server_identifier = auth0_resource_server.this[0].identifier
  permission                 = auth0_resource_server_scope.read_api[0].scope
}

locals {
  # Keyed "<connection>-spa" / "<connection>-docs"; the docs client only exists with a backend
  auth0_connection_client_assignments = merge(
    {
      for name, connection_id in var.auth0_connection_ids : "${name}-spa" => {
        connection_id = connection_id
        client        = "spa"
      } if var.fullstack_app.auth
    },
    {
      for name, connection_id in var.auth0_connection_ids : "${name}-docs" => {
        connection_id = connection_id
        client        = "docs"
      } if var.fullstack_app.auth && var.fullstack_app.backend
    },
  )
}

# Adds this app's clients to shared connections without owning their full client list, so every
# fullstack app can manage its own entries
resource "auth0_connection_client" "this" {
  for_each = local.auth0_connection_client_assignments

  connection_id = each.value.connection_id
  client_id     = each.value.client == "spa" ? auth0_client.this[0].id : auth0_client.docs[0].id
}
