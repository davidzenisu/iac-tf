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
