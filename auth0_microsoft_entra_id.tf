# Entra ID app registration backing the Auth0 Microsoft social connection. Requires the
# Application.ReadWrite.OwnedBy Graph permission granted to the GitHub Actions identity by the bootstrap.
locals {
  auth0_microsoft_connection_enabled = local.fullstack_auth_enabled && var.auth0_microsoft_connection_enabled
}

data "azuread_client_config" "current" {}

data "azuread_application_published_app_ids" "well_known" {}

data "azuread_service_principal" "msgraph" {
  count = local.auth0_microsoft_connection_enabled ? 1 : 0

  client_id = data.azuread_application_published_app_ids.well_known.result["MicrosoftGraph"]
}

resource "azuread_application" "auth0_microsoft" {
  count = local.auth0_microsoft_connection_enabled ? 1 : 0

  display_name     = "Auth0 Microsoft login (${data.auth0_tenant.fullstack[0].domain})"
  owners           = [data.azuread_client_config.current.object_id]
  sign_in_audience = "AzureADandPersonalMicrosoftAccount"

  api {
    requested_access_token_version = 2
  }

  web {
    redirect_uris = ["https://${data.auth0_tenant.fullstack[0].domain}/login/callback"]
  }

  required_resource_access {
    resource_app_id = data.azuread_application_published_app_ids.well_known.result["MicrosoftGraph"]

    dynamic "resource_access" {
      for_each = ["openid", "email", "profile", "offline_access", "User.Read"]

      content {
        id   = data.azuread_service_principal.msgraph[0].oauth2_permission_scope_ids[resource_access.value]
        type = "Scope"
      }
    }
  }
}

# Replaces the client secret every 180 days; the new one is created before the old one is removed
resource "time_rotating" "auth0_microsoft_secret" {
  count = length(azuread_application.auth0_microsoft)

  rotation_days = 180
}

resource "azuread_application_password" "auth0_microsoft" {
  count = length(azuread_application.auth0_microsoft)

  application_id    = azuread_application.auth0_microsoft[0].id
  display_name      = "Auth0 Microsoft social connection"
  end_date_relative = "8760h" # 1 year

  rotate_when_changed = {
    rotation = time_rotating.auth0_microsoft_secret[0].id
  }

  lifecycle {
    create_before_destroy = true
  }
}
