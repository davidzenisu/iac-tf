resource "azurerm_storage_container" "this" {
  count = var.fullstack_app.storage ? 1 : 0

  name                  = "data-${var.fullstack_app.project_name}"
  storage_account_id    = azurerm_storage_account.this[0].id
  container_access_type = "private"
}
