output "cluster_name" {
  description = "Nom du cluster Managed Redis."
  value       = azurerm_managed_redis.this.name
}

output "hostname" {
  description = "Hostname du cluster Redis."
  value       = azurerm_managed_redis.this.hostname
}
