output "azure_backend_storage_account_name" {
  description = "Name of the Azure storage account used for Terraform state backups."
  value       = azurerm_storage_account.backend.name
}

output "azure_backend_storage_container_name" {
  description = "Name of the Azure storage container used for Terraform state backups."
  value       = azurerm_storage_container.terraform_state.name
}
