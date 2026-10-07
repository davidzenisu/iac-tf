resource "azurerm_key_vault" "this" {
  name                = "kv-${substr(replace(var.fullstack_app.project_name, "-", ""), 0, 14)}-${local.suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  rbac_authorization_enabled = true
  purge_protection_enabled   = true
  soft_delete_retention_days = 7
}

resource "azurerm_role_assignment" "github_key_vault" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = azurerm_user_assigned_identity.github.principal_id
}

resource "azurerm_role_assignment" "function_key_vault" {
  count = var.fullstack_app.backend ? 1 : 0

  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.function[0].principal_id
}

resource "azurerm_role_assignment" "terraform_key_vault" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "time_sleep" "key_vault_rbac_propagation" {
  create_duration = "30s"

  triggers = {
    role_assignment_id = azurerm_role_assignment.terraform_key_vault.id
  }
}

resource "azurerm_key_vault_secret" "resource_group_name" {
  name         = "resource-group-name"
  value        = azurerm_resource_group.this.name
  key_vault_id = azurerm_key_vault.this.id

  depends_on = [time_sleep.key_vault_rbac_propagation]
}

resource "azurerm_key_vault_secret" "swa_name" {
  count = var.fullstack_app.frontend ? 1 : 0

  name         = "swa-name"
  value        = azurerm_static_web_app.this[0].name
  key_vault_id = azurerm_key_vault.this.id

  depends_on = [time_sleep.key_vault_rbac_propagation]
}

resource "azurerm_key_vault_secret" "function_app_name" {
  count = var.fullstack_app.backend ? 1 : 0

  name         = "function-app-name"
  value        = azurerm_function_app_flex_consumption.this[0].name
  key_vault_id = azurerm_key_vault.this.id

  depends_on = [time_sleep.key_vault_rbac_propagation]
}

resource "azurerm_key_vault_secret" "storage_account_name" {
  count = var.fullstack_app.backend ? 1 : 0

  name         = "storage-account-name"
  value        = azurerm_storage_account.this[0].name
  key_vault_id = azurerm_key_vault.this.id

  depends_on = [time_sleep.key_vault_rbac_propagation]
}

resource "azurerm_key_vault_secret" "supabase_db_password" {
  count        = var.fullstack_app.database ? 1 : 0
  name         = "database-password"
  value        = random_password.this[0].result
  key_vault_id = azurerm_key_vault.this.id

  depends_on = [time_sleep.key_vault_rbac_propagation]
}

resource "azurerm_key_vault_secret" "database_url" {
  count = var.fullstack_app.database ? 1 : 0

  name         = "database-url"
  value        = replace(data.supabase_pooler.this[0].url["transaction"], "[YOUR-PASSWORD]", random_password.this[0].result)
  key_vault_id = azurerm_key_vault.this.id

  depends_on = [time_sleep.key_vault_rbac_propagation]
}

resource "azurerm_key_vault_secret" "frontend_custom_domain" {
  count = var.fullstack_app.frontend && local.has_custom_domain ? 1 : 0

  name         = "frontend-custom-domain"
  value        = "https://${var.fullstack_app.custom_domain}.${var.zone_name}"
  key_vault_id = azurerm_key_vault.this.id

  depends_on = [time_sleep.key_vault_rbac_propagation]
}

resource "azurerm_key_vault_secret" "api_custom_domain" {
  count = var.fullstack_app.backend && local.has_custom_domain ? 1 : 0

  name         = "api-custom-domain"
  value        = "https://api.${var.fullstack_app.custom_domain}.${var.zone_name}"
  key_vault_id = azurerm_key_vault.this.id

  depends_on = [time_sleep.key_vault_rbac_propagation]
}

resource "azurerm_key_vault_secret" "auth0_domain" {
  count = var.fullstack_app.auth ? 1 : 0

  name         = "auth0-domain"
  value        = data.auth0_tenant.this.domain
  key_vault_id = azurerm_key_vault.this.id

  depends_on = [time_sleep.key_vault_rbac_propagation]
}

resource "azurerm_key_vault_secret" "auth0_client_id" {
  count = var.fullstack_app.auth ? 1 : 0

  name         = "auth0-client-id"
  value        = auth0_client.this[0].client_id
  key_vault_id = azurerm_key_vault.this.id

  depends_on = [time_sleep.key_vault_rbac_propagation]
}
