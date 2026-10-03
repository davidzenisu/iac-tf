resource "azurerm_storage_account" "this" {
  for_each = local.backend_apps

  name = "st${substr(replace(each.value.project_name, "-", ""), 0, 16)}${local.suffixes[each.key]}"

  location                   = azurerm_resource_group.this[each.key].location
  resource_group_name        = azurerm_resource_group.this[each.key].name
  account_tier               = "Standard"
  account_replication_type   = "LRS"
  account_kind               = "StorageV2"
  min_tls_version            = "TLS1_2"
  https_traffic_only_enabled = true

  allow_nested_items_to_be_public = false
  local_user_enabled              = false
}

resource "azurerm_service_plan" "this" {
  for_each = local.backend_apps

  name                = "asp-${each.value.project_name}-${local.suffixes[each.key]}"
  location            = azurerm_resource_group.this[each.key].location
  resource_group_name = azurerm_resource_group.this[each.key].name
  os_type             = "Linux"
  sku_name            = "FC1"
}

resource "azurerm_user_assigned_identity" "function" {
  for_each = local.backend_apps

  name                = "id-${each.value.project_name}-function"
  location            = azurerm_resource_group.this[each.key].location
  resource_group_name = azurerm_resource_group.this[each.key].name
}

resource "azurerm_role_assignment" "function_storage" {
  for_each = local.backend_apps

  scope                = azurerm_storage_account.this[each.key].id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azurerm_user_assigned_identity.function[each.key].principal_id
}

resource "azurerm_function_app_flex_consumption" "this" {
  for_each = local.backend_apps

  name                = "func-${each.value.project_name}-${local.suffixes[each.key]}"
  location            = azurerm_resource_group.this[each.key].location
  resource_group_name = azurerm_resource_group.this[each.key].name
  service_plan_id     = azurerm_service_plan.this[each.key].id

  https_only                                     = true
  webdeploy_publish_basic_authentication_enabled = false

  app_settings = contains(keys(local.database_apps), each.key) ? {
    SUPABASE_DB_PASSWORD = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.supabase_db_password[each.key].versionless_id})"
  } : {}

  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.function[each.key].id,
    ]
  }

  storage_container_type            = "blobContainer"
  storage_container_endpoint        = "${azurerm_storage_account.this[each.key].primary_blob_endpoint}${azurerm_storage_container.this[each.key].name}"
  storage_authentication_type       = "UserAssignedIdentity"
  storage_user_assigned_identity_id = azurerm_user_assigned_identity.function[each.key].id

  runtime_name    = "node"
  runtime_version = "20"

  maximum_instance_count = 50
  instance_memory_in_mb  = 2048

  site_config {}

  depends_on = [
    azurerm_role_assignment.function_storage,
    azurerm_role_assignment.function_key_vault,
  ]
}

resource "azurerm_role_assignment" "github_function" {
  for_each = local.backend_apps

  scope                = azurerm_function_app_flex_consumption.this[each.key].id
  role_definition_name = "Website Contributor"
  principal_id         = azurerm_user_assigned_identity.github[each.key].principal_id
}
