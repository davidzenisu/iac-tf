locals {
  # Optional Auth0 social login providers; only configured ones are stored.
  auth0_social_providers = {
    google = { client_id = var.auth0_google_client_id, client_secret = var.auth0_google_client_secret }
    github = { client_id = var.auth0_github_client_id, client_secret = var.auth0_github_client_secret }
  }

  auth0_social_providers_configured = {
    for name, provider in local.auth0_social_providers : name => provider if provider.client_id != null
  }

  auth0_social_key_vault_secret_values = merge([
    for name, provider in local.auth0_social_providers_configured : {
      "auth0-${name}-client-id"     = provider.client_id
      "auth0-${name}-client-secret" = provider.client_secret
    }
  ]...)

  key_vault_secret_values = merge({
    "azure-tenant-id"        = data.azurerm_client_config.current.tenant_id
    "azure-subscription-id"  = data.azurerm_client_config.current.subscription_id
    "azure-client-id"        = azurerm_user_assigned_identity.github_actions.client_id
    "azure-backend-rg"       = var.azure_backend_resource_group
    "azure-backend-st"       = var.azure_backend_storage_account
    "cloudflare-api-token"   = var.cloudflare_api_token
    "gcp-workload-provider"  = google_iam_workload_identity_pool_provider.github.name
    "gcp-project-id"         = var.gcp_project_id
    "gcp-service-account-id" = google_service_account.github_actions.email
    "supabase-access-token"  = var.supabase_access_token
    "auth0-domain"           = var.auth0_domain
    "auth0-client-id"        = auth0_client.github_actions.client_id
    "auth0-client-secret"    = auth0_client_credentials.github_actions.client_secret
  }, local.auth0_social_key_vault_secret_values)
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

# Lets the main Terraform workflow read optional secrets, e.g. Auth0 social login credentials
resource "azurerm_role_assignment" "github_actions_key_vault_secrets_user" {
  scope                = azurerm_key_vault.bootstrap.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.github_actions.principal_id
  principal_type       = "ServicePrincipal"
}

resource "time_sleep" "key_vault_rbac_propagation" {
  create_duration = "30s"

  triggers = {
    role_assignment_id = azurerm_role_assignment.key_vault_secrets_officer.id
  }
}

resource "azurerm_key_vault_secret" "github_actions" {
  for_each = local.key_vault_secret_values

  name             = each.key
  value_wo         = each.value
  value_wo_version = 1
  key_vault_id     = azurerm_key_vault.bootstrap.id

  depends_on = [time_sleep.key_vault_rbac_propagation]
}
