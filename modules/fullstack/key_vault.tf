resource "azurerm_key_vault" "this" {
  for_each = var.fullstack_apps

  name                = "kv-${substr(replace(each.value.project_name, "-", ""), 0, 14)}-${local.suffixes[each.key]}"
  location            = azurerm_resource_group.this[each.key].location
  resource_group_name = azurerm_resource_group.this[each.key].name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  rbac_authorization_enabled = true
  purge_protection_enabled   = true
  soft_delete_retention_days = 7
}

resource "azurerm_role_assignment" "github_key_vault" {
  for_each = var.fullstack_apps

  scope                = azurerm_key_vault.this[each.key].id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = azurerm_user_assigned_identity.github[each.key].principal_id
}

resource "azurerm_role_assignment" "function_key_vault" {
  for_each = local.backend_apps

  scope                = azurerm_key_vault.this[each.key].id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.function[each.key].principal_id
}

resource "azurerm_role_assignment" "terraform_key_vault" {
  for_each = var.fullstack_apps

  scope                = azurerm_key_vault.this[each.key].id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "time_sleep" "key_vault_rbac_propagation" {
  for_each = var.fullstack_apps

  create_duration = "30s"

  triggers = {
    role_assignment_id = azurerm_role_assignment.terraform_key_vault[each.key].id
  }
}

resource "azurerm_key_vault_secret" "resource_group_name" {
  for_each = var.fullstack_apps

  name         = "resource-group-name"
  value        = azurerm_resource_group.this[each.key].name
  key_vault_id = azurerm_key_vault.this[each.key].id

  depends_on = [time_sleep.key_vault_rbac_propagation]
}

resource "azurerm_key_vault_secret" "swa_name" {
  for_each = local.frontend_apps

  name         = "swa-name"
  value        = azurerm_static_web_app.this[each.key].name
  key_vault_id = azurerm_key_vault.this[each.key].id

  depends_on = [time_sleep.key_vault_rbac_propagation]
}

resource "azurerm_key_vault_secret" "function_app_name" {
  for_each = local.backend_apps

  name         = "function-app-name"
  value        = azurerm_function_app_flex_consumption.this[each.key].name
  key_vault_id = azurerm_key_vault.this[each.key].id

  depends_on = [time_sleep.key_vault_rbac_propagation]
}

resource "azurerm_key_vault_secret" "storage_account_name" {
  for_each = local.backend_apps

  name         = "storage-account-name"
  value        = azurerm_storage_account.this[each.key].name
  key_vault_id = azurerm_key_vault.this[each.key].id

  depends_on = [time_sleep.key_vault_rbac_propagation]
}

resource "azurerm_key_vault_secret" "supabase_db_password" {
  for_each     = local.database_apps
  name         = "database-password"
  value        = random_password.this[each.key].result
  key_vault_id = azurerm_key_vault.this[each.key].id

  depends_on = [time_sleep.key_vault_rbac_propagation]
}

resource "azurerm_key_vault_secret" "database_url" {
  for_each = local.database_apps

  name         = "database-url"
  value        = replace(data.supabase_pooler.this[each.key].url["transaction"], "[YOUR-PASSWORD]", random_password.this[each.key].result)
  key_vault_id = azurerm_key_vault.this[each.key].id

  depends_on = [time_sleep.key_vault_rbac_propagation]
}

resource "azurerm_key_vault_secret" "frontend_custom_domain" {
  for_each = local.custom_domain_apps

  name         = "frontend-custom-domain"
  value        = "https://${each.value.custom_domain}.${var.zone_name}"
  key_vault_id = azurerm_key_vault.this[each.key].id

  depends_on = [time_sleep.key_vault_rbac_propagation]
}

resource "azurerm_key_vault_secret" "api_custom_domain" {
  for_each = local.api_custom_domain_apps

  name         = "api-custom-domain"
  value        = "https://api.${each.value.custom_domain}.${var.zone_name}"
  key_vault_id = azurerm_key_vault.this[each.key].id

  depends_on = [time_sleep.key_vault_rbac_propagation]
}

resource "azurerm_key_vault_secret" "auth0_domain" {
  for_each = local.auth_apps

  name         = "auth0-domain"
  value        = data.auth0_tenant.this.domain
  key_vault_id = azurerm_key_vault.this[each.key].id

  depends_on = [time_sleep.key_vault_rbac_propagation]
}

resource "azurerm_key_vault_secret" "auth0_client_id" {
  for_each = local.auth_apps

  name         = "auth0-client-id"
  value        = auth0_client.this[each.key].client_id
  key_vault_id = azurerm_key_vault.this[each.key].id

  depends_on = [time_sleep.key_vault_rbac_propagation]
}
