output "id" {
  description = "ID du Key Vault."
  value       = azurerm_key_vault.this.id
}

output "name" {
  description = "Nom du Key Vault."
  value       = azurerm_key_vault.this.name
}

output "uri" {
  description = "URI du Key Vault."
  value       = azurerm_key_vault.this.vault_uri
}
