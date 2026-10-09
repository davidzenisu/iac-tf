data "azurerm_client_config" "current" {}

locals {
  suffix            = substr(sha1("${data.azurerm_client_config.current.subscription_id}/${var.fullstack_app.project_name}"), 0, 6)
  has_custom_domain = var.fullstack_app.custom_domain != null
  api_audience      = local.has_custom_domain && var.zone_name != null ? "https://api.${var.fullstack_app.custom_domain}.${var.zone_name}" : null

  function_deployment_container_name = var.fullstack_app.storage ? one(azurerm_storage_container.this[*].name) : one(azurerm_storage_container.deployment[*].name)
}
