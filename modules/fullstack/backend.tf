resource "azurerm_storage_account" "this" {
  count = var.fullstack_app.backend ? 1 : 0

  name = "st${substr(replace(var.fullstack_app.project_name, "-", ""), 0, 16)}${local.suffix}"

  location                   = azurerm_resource_group.this.location
  resource_group_name        = azurerm_resource_group.this.name
  account_tier               = "Standard"
  account_replication_type   = "LRS"
  account_kind               = "StorageV2"
  min_tls_version            = "TLS1_2"
  https_traffic_only_enabled = true

  allow_nested_items_to_be_public = false
  local_user_enabled              = false
}

resource "azurerm_service_plan" "this" {
  count = var.fullstack_app.backend ? 1 : 0

  name                = "asp-${var.fullstack_app.project_name}-${local.suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  os_type             = "Linux"
  sku_name            = "FC1"
}

resource "azurerm_user_assigned_identity" "function" {
  count = var.fullstack_app.backend ? 1 : 0

  name                = "id-${var.fullstack_app.project_name}-function"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_role_assignment" "function_storage" {
  count = var.fullstack_app.backend ? 1 : 0

  scope                = azurerm_storage_account.this[0].id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azurerm_user_assigned_identity.function[0].principal_id
}

resource "azurerm_function_app_flex_consumption" "this" {
  count = var.fullstack_app.backend ? 1 : 0

  name                = "func-${var.fullstack_app.project_name}-${local.suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  service_plan_id     = azurerm_service_plan.this[0].id

  https_only                                     = true
  webdeploy_publish_basic_authentication_enabled = false

  app_settings = merge(
    var.fullstack_app.database ? {
      SUPABASE_DB_PASSWORD = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.supabase_db_password[0].versionless_id})"
      DATABASE_URL         = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.database_url[0].versionless_id})"

      # Until https://github.com/hashicorp/terraform-provider-azurerm/issues/29693 is resolved
      AzureWebJobsStorage__credential  = "managedidentity"
      AzureWebJobsStorage__clientId    = azurerm_user_assigned_identity.function[0].client_id
      AzureWebJobsStorage__accountname = azurerm_storage_account.this[0].name
    } : {},
    var.fullstack_app.frontend && local.has_custom_domain ? {
      FRONTEND_URL = "https://${var.fullstack_app.custom_domain}.${var.zone_name}"
    } : {},
  )

  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.function[0].id,
    ]
  }

  storage_container_type            = "blobContainer"
  storage_container_endpoint        = "${azurerm_storage_account.this[0].primary_blob_endpoint}${azurerm_storage_container.this[0].name}"
  storage_authentication_type       = "UserAssignedIdentity"
  storage_user_assigned_identity_id = azurerm_user_assigned_identity.function[0].id

  runtime_name    = var.fullstack_app.function_runtime_name
  runtime_version = var.fullstack_app.function_runtime_version

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
  count = var.fullstack_app.backend ? 1 : 0

  type        = "Microsoft.Web/sites@2024-04-01"
  resource_id = azurerm_function_app_flex_consumption.this[0].id

  body = {
    properties = {
      keyVaultReferenceIdentity = azurerm_user_assigned_identity.function[0].id
    }
  }
}

resource "azurerm_role_assignment" "github_function" {
  count = var.fullstack_app.backend ? 1 : 0

  scope                = azurerm_function_app_flex_consumption.this[0].id
  role_definition_name = "Website Contributor"
  principal_id         = azurerm_user_assigned_identity.github.principal_id
}

resource "cloudflare_record" "function_app" {
  count = var.fullstack_app.backend ? 1 : 0

  zone_id = var.zone_id
  name    = "api.${var.fullstack_app.custom_domain}"
  content = azurerm_function_app_flex_consumption.this[0].default_hostname
  type    = "CNAME"
  proxied = false
}

resource "time_sleep" "backend_custom_domain_wait" {
  count = var.fullstack_app.backend ? 1 : 0

  create_duration  = "300s"
  destroy_duration = "0s"

  depends_on = [
    cloudflare_record.function_app,
  ]
}

resource "azurerm_app_service_custom_hostname_binding" "this" {
  count = var.fullstack_app.backend ? 1 : 0

  hostname            = "api.${var.fullstack_app.custom_domain}.${var.zone_name}"
  app_service_name    = azurerm_function_app_flex_consumption.this[0].name
  resource_group_name = azurerm_function_app_flex_consumption.this[0].resource_group_name

  depends_on = [
    cloudflare_record.function_app,
    time_sleep.backend_custom_domain_wait,
  ]
}

# https://github.com/hashicorp/terraform-provider-azurerm/issues/31884
resource "azapi_resource" "backend_managed_cert" {
  count = var.fullstack_app.backend ? 1 : 0

  type      = "Microsoft.Web/sites/certificates@2025-03-01"
  name      = "${azurerm_function_app_flex_consumption.this[0].name}-cert"
  parent_id = azurerm_function_app_flex_consumption.this[0].id
  location  = azurerm_function_app_flex_consumption.this[0].location
  body = {
    properties = {
      canonicalName          = "api.${var.fullstack_app.custom_domain}.${var.zone_name}"
      domainValidationMethod = "CNAME"
      hostNames = [
        "api.${var.fullstack_app.custom_domain}.${var.zone_name}"
      ]
    }
  }

  depends_on = [
    azurerm_app_service_custom_hostname_binding.this,
  ]
}

resource "azapi_update_resource" "backend_https_binding" {
  count = var.fullstack_app.backend ? 1 : 0

  type        = "Microsoft.Web/sites/hostNameBindings@2025-03-01"
  resource_id = azurerm_app_service_custom_hostname_binding.this[0].id

  body = {
    properties = {
      sslState   = "SniEnabled"
      thumbprint = azapi_resource.backend_managed_cert[0].output.properties.thumbprint
    }
  }

  depends_on = [
    azapi_resource.backend_managed_cert,
  ]
}
