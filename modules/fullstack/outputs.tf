output "github_credentials" {
  description = "Client IDs and tenant/subscription identifiers for GitHub Actions OIDC login."
  value = {
    client_id       = azurerm_user_assigned_identity.github.client_id
    tenant_id       = data.azurerm_client_config.current.tenant_id
    subscription_id = data.azurerm_client_config.current.subscription_id
  }
}

output "auth0_client_id" {
  description = "Client ID for the Auth0 application, if enabled."
  value       = try(auth0_client.this[0].client_id, null)
}

output "supabase_project_id" {
  description = "Project reference for the Supabase project, if enabled."
  value       = try(supabase_project.this[0].id, null)
}
