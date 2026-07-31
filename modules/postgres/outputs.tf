output "server_name" {
  description = "Nom du serveur PostgreSQL."
  value       = azurerm_postgresql_flexible_server.this.name
}

output "fqdn" {
  description = "FQDN du serveur PostgreSQL."
  value       = azurerm_postgresql_flexible_server.this.fqdn
}

output "database_name" {
  description = "Nom de la base applicative."
  value       = azurerm_postgresql_flexible_server_database.app.name
}
