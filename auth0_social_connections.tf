locals {
  auth0_social_providers = {
    google = {
      strategy         = "google-oauth2"
      scopes           = ["email", "profile"]
      strategy_version = null
    }
    github = {
      strategy         = "github"
      scopes           = ["email", "read_user"]
      strategy_version = null
    }
    microsoft = {
      strategy         = "windowslive"
      scopes           = ["signin", "graph_user"]
      strategy_version = 2
    }
  }

  # Missing GitHub secrets are passed as empty strings, so treat those as unset.
  bootstrap_key_vault_configured = try(
    length(var.bootstrap_key_vault_name) > 0 && length(var.bootstrap_key_vault_resource_group_name) > 0,
    false
  )

  auth0_social_providers_activated = {
    for name, provider in local.auth0_social_providers : name => provider
    if local.fullstack_auth_enabled && var.auth0_social_connections[name]
  }

  bootstrap_key_vault_secret_names = try(data.azurerm_key_vault_secrets.bootstrap[0].names, [])

  # Activated providers whose credentials exist in the bootstrap Key Vault
  auth0_social_connections = {
    for name, provider in local.auth0_social_providers_activated : name => provider
    if contains(local.bootstrap_key_vault_secret_names, "auth0-${name}-client-id") &&
    contains(local.bootstrap_key_vault_secret_names, "auth0-${name}-client-secret")
  }

  # SPA and docs clients of every fullstack app with auth enabled
  auth0_social_enabled_clients = compact(flatten([
    for app in module.fullstack : [app.auth0_client_id, app.auth0_docs_client_id]
  ]))
}

data "azurerm_key_vault" "bootstrap" {
  count = local.bootstrap_key_vault_configured && length(local.auth0_social_providers_activated) > 0 ? 1 : 0

  name                = var.bootstrap_key_vault_name
  resource_group_name = var.bootstrap_key_vault_resource_group_name
}

data "azurerm_key_vault_secrets" "bootstrap" {
  count = length(data.azurerm_key_vault.bootstrap)

  key_vault_id = data.azurerm_key_vault.bootstrap[0].id
}

data "azurerm_key_vault_secret" "auth0_social_client_id" {
  for_each = local.auth0_social_connections

  name         = "auth0-${each.key}-client-id"
  key_vault_id = data.azurerm_key_vault.bootstrap[0].id
}

data "azurerm_key_vault_secret" "auth0_social_client_secret" {
  for_each = local.auth0_social_connections

  name         = "auth0-${each.key}-client-secret"
  key_vault_id = data.azurerm_key_vault.bootstrap[0].id
}

resource "auth0_connection" "social" {
  for_each = local.auth0_social_connections

  name     = each.value.strategy
  strategy = each.value.strategy

  options {
    client_id                = data.azurerm_key_vault_secret.auth0_social_client_id[each.key].value
    client_secret            = data.azurerm_key_vault_secret.auth0_social_client_secret[each.key].value
    scopes                   = each.value.scopes
    strategy_version         = each.value.strategy_version
    set_user_root_attributes = "on_each_login"
  }
}

resource "auth0_connection_clients" "social" {
  for_each = local.auth0_social_connections

  connection_id   = auth0_connection.social[each.key].id
  enabled_clients = local.auth0_social_enabled_clients
}

check "auth0_social_connection_secrets" {
  assert {
    condition = alltrue([
      for name in keys(local.auth0_social_providers_activated) : contains(keys(local.auth0_social_connections), name)
    ])
    error_message = "Some activated Auth0 social connections were skipped because the bootstrap Key Vault isn't configured or lacks their auth0-<provider>-client-id/-client-secret secrets."
  }
}
