locals {
  auth0_social_providers = {
    google = {
      strategy         = "google-oauth2"
      scopes           = ["email", "profile"]
      strategy_version = null
      # Auth0 developer keys are used while no own credentials exist; not meant for production
      dev_keys_fallback = true
      entra_id_app      = false
    }
    github = {
      strategy          = "github"
      scopes            = ["email", "read_user"]
      strategy_version  = null
      dev_keys_fallback = false
      entra_id_app      = false
    }
    microsoft = {
      strategy          = "windowslive"
      scopes            = ["signin", "graph_user"]
      strategy_version  = 2
      dev_keys_fallback = false
      # Credentials come from the Entra ID app registration in auth0_microsoft_entra_id.tf
      entra_id_app = true
    }
  }

  # Set by the pipeline from the bootstrap Key Vault; kept apart from the provider settings so the
  # sensitive secrets never decide which connections exist
  auth0_social_client_ids = {
    google = var.auth0_google_client_id
    github = var.auth0_github_client_id
  }
  auth0_social_client_secrets = {
    google = var.auth0_google_client_secret
    github = var.auth0_github_client_secret
  }

  auth0_social_providers_activated = {
    for name, provider in local.auth0_social_providers : name => provider
    if local.fullstack_auth_enabled && var.auth0_social_connections[name]
  }

  # Activated providers with own credentials
  auth0_social_connections_with_credentials = {
    for name, provider in local.auth0_social_providers_activated : name => provider
    if !provider.entra_id_app && try(length(trimspace(local.auth0_social_client_ids[name])) > 0, false)
  }

  # Activated providers without credentials that fall back to Auth0 developer keys
  auth0_social_connections_with_dev_keys = {
    for name, provider in local.auth0_social_providers_activated : name => provider
    if provider.dev_keys_fallback && !contains(keys(local.auth0_social_connections_with_credentials), name)
  }

  # Activated providers whose app registration is created in Entra ID
  auth0_social_connections_with_entra_id_app = {
    for name, provider in local.auth0_social_providers_activated : name => provider
    if provider.entra_id_app
  }

  auth0_social_connections = merge(
    local.auth0_social_connections_with_credentials,
    local.auth0_social_connections_with_dev_keys,
    local.auth0_social_connections_with_entra_id_app,
  )

  # SPA and docs clients of every fullstack app with auth enabled
  auth0_social_enabled_clients = compact(flatten([
    for app in module.fullstack : [app.auth0_client_id, app.auth0_docs_client_id]
  ]))
}

resource "auth0_connection" "social" {
  for_each = local.auth0_social_connections

  name     = each.value.strategy
  strategy = each.value.strategy

  options {
    # Empty credentials make Auth0 use its developer keys
    client_id = (
      each.value.entra_id_app
      ? one(azuread_application.auth0_microsoft[*].client_id)
      : contains(keys(local.auth0_social_connections_with_credentials), each.key) ? local.auth0_social_client_ids[each.key] : ""
    )
    client_secret = (
      each.value.entra_id_app
      ? one(azuread_application_password.auth0_microsoft[*].value)
      : contains(keys(local.auth0_social_connections_with_credentials), each.key) ? local.auth0_social_client_secrets[each.key] : ""
    )
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
    error_message = "Some activated Auth0 social connections were skipped because their auth0-<provider>-client-id/-client-secret secrets don't exist in the bootstrap Key Vault."
  }

  assert {
    condition     = length(local.auth0_social_connections_with_dev_keys) == 0
    error_message = "Auth0 social connections ${join(", ", keys(local.auth0_social_connections_with_dev_keys))} use Auth0 developer keys, which are not meant for production. Add auth0-<provider>-client-id/-client-secret to the bootstrap Key Vault to use your own credentials."
  }
}
