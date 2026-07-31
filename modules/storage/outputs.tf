output "account_name" {
  description = "Nom du storage account."
  value       = azurerm_storage_account.this.name
}

output "container_name" {
  description = "Nom du container applicatif."
  value       = azurerm_storage_container.app.name
}
