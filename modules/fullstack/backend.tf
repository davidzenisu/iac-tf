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
    DATABASE_URL         = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.database_url[each.key].versionless_id})"

    # Until https://github.com/hashicorp/terraform-provider-azurerm/issues/29693 is resolved
    AzureWebJobsStorage__credential  = "managedidentity"
    AzureWebJobsStorage__clientId    = azurerm_user_assigned_identity.function[each.key].client_id
    AzureWebJobsStorage__accountname = azurerm_storage_account.this[each.key].name
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

  runtime_name    = each.value.function_runtime_name
  runtime_version = each.value.function_runtime_version

  maximum_instance_count = 50
  instance_memory_in_mb  = 2048

  site_config {}

  depends_on = [
    azurerm_role_assignment.function_storage,
    azurerm_role_assignment.function_key_vault,
  ]
}

# https://github.com/hashicorp/terraform-provider-azurerm/issues/28928
resource "azapi_update_resource" "function_key_vault_reference_identity" {
  for_each = local.backend_apps

  type        = "Microsoft.Web/sites@2024-04-01"
  resource_id = azurerm_function_app_flex_consumption.this[each.key].id

  body = {
    properties = {
      keyVaultReferenceIdentity = azurerm_user_assigned_identity.function[each.key].id
    }
  }
}

resource "azurerm_role_assignment" "github_function" {
  for_each = local.backend_apps

  scope                = azurerm_function_app_flex_consumption.this[each.key].id
  role_definition_name = "Website Contributor"
  principal_id         = azurerm_user_assigned_identity.github[each.key].principal_id
}

resource "cloudflare_record" "function_app" {
  for_each = local.backend_apps

  zone_id = var.zone_id
  name    = "api.${each.value.custom_domain}"
  content = azurerm_function_app_flex_consumption.this[each.key].default_hostname
  type    = "CNAME"
  proxied = false
}

resource "time_sleep" "backend_custom_domain_wait" {
  for_each = local.backend_apps

  create_duration  = "300s"
  destroy_duration = "0s"

  depends_on = [
    cloudflare_record.function_app,
  ]
}

resource "azurerm_app_service_custom_hostname_binding" "this" {
  for_each = local.backend_apps

  hostname            = "api.${each.value.custom_domain}.${var.zone_name}"
  app_service_name    = azurerm_function_app_flex_consumption.this[each.key].name
  resource_group_name = azurerm_function_app_flex_consumption.this[each.key].resource_group_name

  depends_on = [
    cloudflare_record.function_app,
    time_sleep.backend_custom_domain_wait,
  ]
}

# https://github.com/hashicorp/terraform-provider-azurerm/issues/31884
resource "azapi_resource" "backend_managed_cert" {
  for_each = local.backend_apps

  type      = "Microsoft.Web/sites/certificates@2025-03-01"
  name      = "${azurerm_function_app_flex_consumption.this[each.key].name}-cert"
  parent_id = azurerm_function_app_flex_consumption.this[each.key].id
  location  = azurerm_function_app_flex_consumption.this[each.key].location
  body = {
    properties = {
      canonicalName          = "api.${each.value.custom_domain}.${var.zone_name}"
      domainValidationMethod = "CNAME"
      hostNames = [
        "api.${each.value.custom_domain}.${var.zone_name}"
      ]
    }
  }

  depends_on = [
    azurerm_app_service_custom_hostname_binding.this,
  ]
}

resource "azapi_update_resource" "backend_https_binding" {
  for_each = local.backend_apps

  type        = "Microsoft.Web/sites/hostNameBindings@2025-03-01"
  resource_id = azurerm_app_service_custom_hostname_binding.this[each.key].id

  body = {
    properties = {
      sslState   = "SniEnabled"
      thumbprint = azapi_resource.backend_managed_cert[each.key].output.properties.thumbprint
    }
  }

  depends_on = [
    azapi_resource.backend_managed_cert,
  ]
}
