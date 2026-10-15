locals {
  auth0_social_providers = {
    google = {
      strategy = "google-oauth2"
      scopes   = ["email", "profile"]
    }
    github = {
      strategy = "github"
      scopes   = ["email", "read_user"]
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
  auth0_social_connections = {
    for name, provider in local.auth0_social_providers : name => provider
    if local.fullstack_auth_enabled && try(length(trimspace(local.auth0_social_client_ids[name])) > 0, false)
  }
}

resource "auth0_connection" "social" {
  for_each = local.auth0_social_connections

  name     = each.value.strategy
  strategy = each.value.strategy

  options {
    client_id                = local.auth0_social_client_ids[each.key]
    client_secret            = local.auth0_social_client_secrets[each.key]
    scopes                   = each.value.scopes
    set_user_root_attributes = "on_each_login"
  }
}

# Adopts the google-oauth2 connection that new Auth0 tenants come with, which would otherwise block
# creating a connection of the same name. Importing keeps the users who already signed in with it.
# The import only runs while the Google connection is part of the configuration.
import {
  for_each = {
    for name, connection_id in { google = var.auth0_google_connection_id } : name => connection_id
    if connection_id != null && contains(keys(local.auth0_social_connections), name)
  }

  to = auth0_connection.social[each.key]
  id = each.value
}
