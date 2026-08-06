# Azure Managed Redis = azurerm_managed_redis (ressource native). 
#La base "default" se configure dans un bloc default_database intégré au cluster.
resource "azurerm_managed_redis" "this" {
  name                = "redis-${var.owner}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = var.redis_sku

  default_database {
    access_keys_authentication_enabled = true
    clustering_policy                  = "OSSCluster"
    eviction_policy                    = "VolatileLRU"
  }

  tags = merge(var.tags, { component = "redis" })
}

# Clé et host stockés dans Key Vault, jamais exposés en clair.
#tfsec:ignore:azure-keyvault-ensure-secret-expiry
#tfsec:ignore:azure-keyvault-content-type-for-secret
resource "azurerm_key_vault_secret" "redis_key" {
  name         = "redis-primary-key"
  value        = azurerm_managed_redis.this.default_database[0].primary_access_key
  key_vault_id = var.key_vault_id
}

#tfsec:ignore:azure-keyvault-ensure-secret-expiry
#tfsec:ignore:azure-keyvault-content-type-for-secret
resource "azurerm_key_vault_secret" "redis_host" {
  name         = "redis-host"
  value        = azurerm_managed_redis.this.hostname
  key_vault_id = var.key_vault_id
}
