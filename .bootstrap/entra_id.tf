data "azuread_application_published_app_ids" "well_known" {}

data "azuread_service_principal" "msgraph" {
  client_id = data.azuread_application_published_app_ids.well_known.result["MicrosoftGraph"]
}

# Lets the main Terraform workflow create and manage the Entra ID app registrations it owns,
# e.g. the one used by the Auth0 Microsoft social connection. Granting it requires the
# Privileged Role Administrator or Global Administrator role.
resource "azuread_app_role_assignment" "github_actions_application_owned_by" {
  app_role_id         = data.azuread_service_principal.msgraph.app_role_ids["Application.ReadWrite.OwnedBy"]
  principal_object_id = azurerm_user_assigned_identity.github_actions.principal_id
  resource_object_id  = data.azuread_service_principal.msgraph.object_id
}
