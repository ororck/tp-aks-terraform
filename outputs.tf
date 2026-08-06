output "key_vault_name" {
  description = "Nom du Key Vault (la CI le retrouve aussi par tags)."
  value       = module.keyvault.name
}

output "postgres_fqdn" {
  description = "FQDN du serveur PostgreSQL."
  value       = module.postgres.fqdn
}

output "postgres_database" {
  description = "Nom de la base applicative."
  value       = module.postgres.database_name
}

output "redis_hostname" {
  description = "Hostname du cluster Redis."
  value       = module.redis.hostname
}

output "storage_account_name" {
  description = "Nom du storage account."
  value       = module.storage.account_name
}

output "namespace" {
  description = "Namespace Kubernetes dédié."
  value       = module.kubernetes.namespace
}

output "acr_login_server" {
  description = "Serveur de connexion de l'ACR (la CI le retrouve aussi par tags)."
  value       = module.acr.login_server
}