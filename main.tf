# -----------------------------------------------------------------------------
# Câblage des modules. Ordre logique des dépendances :
# keyvault -> (postgres, redis écrivent leurs secrets dedans)
# storage et kubernetes sont indépendants.
# -----------------------------------------------------------------------------

module "keyvault" {
  source = "./modules/keyvault"

  owner                 = var.owner
  location              = var.location
  resource_group_name   = data.azurerm_resource_group.dedicated.name
  tenant_id             = data.azurerm_client_config.current.tenant_id
  cluster_egress_ip     = local.cluster_egress_ip
  deployer_principal_id = data.azurerm_client_config.current.object_id
  tags                  = local.common_tags
}

module "postgres" {
  source = "./modules/postgres"

  owner               = var.owner
  location            = var.location
  resource_group_name = data.azurerm_resource_group.dedicated.name
  postgres_version    = var.postgres_version
  postgres_sku        = var.postgres_sku
  postgres_storage_mb = var.postgres_storage_mb
  admin_login         = var.postgres_admin_login
  database_name       = var.postgres_database_name
  cluster_egress_ip   = local.cluster_egress_ip
  key_vault_id        = module.keyvault.id
  tags                = local.common_tags
}

module "redis" {
  source = "./modules/redis"

  owner               = var.owner
  location            = var.location
  resource_group_name = data.azurerm_resource_group.dedicated.name
  redis_sku           = var.redis_sku
  key_vault_id        = module.keyvault.id
  tags                = local.common_tags
}

module "storage" {
  source = "./modules/storage"

  owner_slug          = local.owner_slug
  location            = var.location
  resource_group_name = data.azurerm_resource_group.dedicated.name
  account_tier        = var.storage_account_tier
  replication         = var.storage_replication
  cluster_egress_ip   = local.cluster_egress_ip
  tags                = local.common_tags
}

module "kubernetes" {
  source = "./modules/kubernetes"

  namespace = var.namespace
  owner     = var.owner
}
