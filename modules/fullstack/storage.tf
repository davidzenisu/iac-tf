resource "azurerm_storage_container" "this" {
  for_each = local.storage_apps

  name                  = "data-${each.value.project_name}"
  storage_account_id    = azurerm_storage_account.this[each.key].id
  container_access_type = "private"
}
