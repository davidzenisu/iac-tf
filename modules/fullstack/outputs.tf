output "github_credentials" {
  description = "Client IDs and tenant/subscription identifiers for GitHub Actions OIDC login."
  value = {
    for key, identity in azurerm_user_assigned_identity.github :
    key => {
      client_id       = identity.client_id
      tenant_id       = data.azurerm_client_config.current.tenant_id
      subscription_id = data.azurerm_client_config.current.subscription_id
    }
  }
}

output "auth0_client_ids" {
  description = "Client IDs for the Auth0 applications."
  value = {
    for key, client in auth0_client.this : key => client.client_id
  }
}

output "supabase_project_ids" {
  description = "Project references for the Supabase projects."
  value = {
    for key, project in supabase_project.this : key => project.id
  }
}
