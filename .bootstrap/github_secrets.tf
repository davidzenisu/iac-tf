locals {
  github_secret_values = {
    AZURE_TENANT_ID        = data.azurerm_client_config.current.tenant_id
    AZURE_SUBSCRIPTION_ID  = data.azurerm_client_config.current.subscription_id
    AZURE_CLIENT_ID        = azurerm_user_assigned_identity.github_actions.client_id
    AZURE_BACKEND_RG       = var.azure_backend_resource_group
    AZURE_BACKEND_ST       = var.azure_backend_storage_account
    CLOUDFLARE_API_TOKEN   = var.cloudflare_api_token
    GCP_WORKLOAD_PROVIDER  = google_iam_workload_identity_pool_provider.github.name
    GCP_PROJECT_ID         = var.gcp_project_id
    GCP_SERVICE_ACCOUNT_ID = google_service_account.github_actions.email
  }
}

resource "github_actions_secret" "this" {
  for_each = local.github_secret_values

  repository  = var.github_repository
  secret_name = each.key
  value       = each.value
}
