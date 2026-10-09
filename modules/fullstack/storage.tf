resource "azurerm_storage_container" "this" {
  count = var.fullstack_app.backend && var.fullstack_app.storage ? 1 : 0

  name                  = "data-${var.fullstack_app.project_name}"
  storage_account_id    = azurerm_storage_account.this[0].id
  container_access_type = "private"
}

# Flex consumption always needs a deployment container; reuse the data
# container when storage is enabled, otherwise create a dedicated one.
resource "azurerm_storage_container" "deployment" {
  count = var.fullstack_app.backend && !var.fullstack_app.storage ? 1 : 0

  name                  = "deployment-${var.fullstack_app.project_name}"
  storage_account_id    = azurerm_storage_account.this[0].id
  container_access_type = "private"
}
