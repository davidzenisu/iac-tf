locals {
  # Missing GitHub secrets are passed as empty strings, so treat those as unset.
  auth0_social_connections = {
    for name, connection in {
      google = {
        strategy         = "google-oauth2"
        client_id        = var.auth0_google_client_id
        client_secret    = var.auth0_google_client_secret
        scopes           = ["email", "profile"]
        strategy_version = null
      }
      github = {
        strategy         = "github"
        client_id        = var.auth0_github_client_id
        client_secret    = var.auth0_github_client_secret
        scopes           = ["email", "read_user"]
        strategy_version = null
      }
      microsoft = {
        strategy         = "windowslive"
        client_id        = var.auth0_microsoft_client_id
        client_secret    = var.auth0_microsoft_client_secret
        scopes           = ["signin", "graph_user"]
        strategy_version = 2
      }
    } : name => connection
    if local.fullstack_auth_enabled && try(length(trimspace(connection.client_id)) > 0, false)
  }

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
    client_id                = each.value.client_id
    client_secret            = each.value.client_secret
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
