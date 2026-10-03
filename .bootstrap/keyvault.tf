locals {
  key_vault_secret_values = {
    "azure-tenant-id"        = data.azurerm_client_config.current.tenant_id
    "azure-subscription-id"  = data.azurerm_client_config.current.subscription_id
    "azure-client-id"        = azurerm_user_assigned_identity.github_actions.client_id
    "azure-backend-rg"       = var.azure_backend_resource_group
    "azure-backend-st"       = var.azure_backend_storage_account
    "cloudflare-api-token"   = var.cloudflare_api_token
    "gcp-workload-provider"  = google_iam_workload_identity_pool_provider.github.name
    "gcp-project-id"         = var.gcp_project_id
    "gcp-service-account-id" = google_service_account.github_actions.email
  }
}

resource "azurerm_key_vault" "bootstrap" {
  name                = var.azure_key_vault_name
  location            = var.azure_location
  resource_group_name = var.azure_backend_resource_group
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  rbac_authorization_enabled = true
  soft_delete_retention_days = 7
  purge_protection_enabled   = true
}

resource "azurerm_role_assignment" "key_vault_secrets_officer" {
  scope                = azurerm_key_vault.bootstrap.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
  principal_type       = "User"
}

resource "time_sleep" "key_vault_rbac_propagation" {
  create_duration = "30s"

  triggers = {
    role_assignment_id = azurerm_role_assignment.key_vault_secrets_officer.id
  }
}

resource "azurerm_key_vault_secret" "github_actions" {
  for_each = local.key_vault_secret_values

  name         = each.key
  value        = each.value
  key_vault_id = azurerm_key_vault.bootstrap.id

  depends_on = [time_sleep.key_vault_rbac_propagation]
}
