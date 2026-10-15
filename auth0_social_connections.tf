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

  # Providers whose credentials are set; the variable validations ensure the secret is set too
  auth0_social_connections_with_credentials = {
    for name, provider in local.auth0_social_providers : name => provider
    if local.fullstack_auth_enabled && try(length(trimspace(local.auth0_social_client_ids[name])) > 0, false)
  }

  auth0_social_connections = merge(
    local.auth0_social_connections_with_credentials,
    # Credentials come from the Entra ID app registration in auth0_microsoft_entra_id.tf
    {
      for name, provider in {
        microsoft = {
          strategy         = "windowslive"
          scopes           = ["signin", "graph_user"]
          strategy_version = 2
        }
      } : name => provider if local.auth0_microsoft_connection_enabled
    },
  )
}

resource "auth0_connection" "social" {
  for_each = local.auth0_social_connections

  name     = each.value.strategy
  strategy = each.value.strategy

  options {
    client_id = (
      each.key == "microsoft"
      ? one(azuread_application.auth0_microsoft[*].client_id)
      : local.auth0_social_client_ids[each.key]
    )
    client_secret = (
      each.key == "microsoft"
      ? one(azuread_application_password.auth0_microsoft[*].value)
      : local.auth0_social_client_secrets[each.key]
    )
    scopes                   = each.value.scopes
    strategy_version         = each.value.strategy_version
    set_user_root_attributes = "on_each_login"
  }
}
