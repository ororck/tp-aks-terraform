# -----------------------------------------------------------------------------
# Variables racine : déclarées avec descriptions et validations détaillées.
# Les modules redéclarent les leurs de façon minimale.
# -----------------------------------------------------------------------------

variable "owner" {
  description = "Identifiant du propriétaire, utilisé dans les tags et les noms de ressources."
  type        = string
  default     = "mohamed-saidi"
}

variable "location" {
  description = "Région Azure de toutes les ressources créées."
  type        = string
  default     = "francecentral"
}

variable "resource_group_name" {
  description = "Nom du resource group dédié (fourni, référencé en data source)."
  type        = string
  default     = "msaidiRG"
}

# --- Cluster mutualisé (référencé) -------------------------------------------

variable "aks_name" {
  description = "Nom du cluster AKS mutualisé fourni."
  type        = string
  default     = "aks-nonprod-prf2026"
}

variable "aks_resource_group" {
  description = "Resource group du cluster AKS mutualisé."
  type        = string
  default     = "rg-shared-prf2026"
}

variable "namespace" {
  description = "Namespace Kubernetes dédié, créé dans le cluster mutualisé."
  type        = string
  default     = "mohamed-saidi"
}

# --- PostgreSQL --------------------------------------------------------------

variable "postgres_sku" {
  description = "SKU du serveur PostgreSQL Flexible (non-prod : Burstable)."
  type        = string
  default     = "B_Standard_B1ms"
}

variable "postgres_version" {
  description = "Version majeure de PostgreSQL."
  type        = string
  default     = "16"
}

variable "postgres_storage_mb" {
  description = "Stockage du serveur PostgreSQL en Mo."
  type        = number
  default     = 32768
}

variable "postgres_admin_login" {
  description = "Login administrateur PostgreSQL (le mot de passe est généré et stocké en Key Vault)."
  type        = string
  default     = "pgadmin"
}

variable "postgres_database_name" {
  description = "Nom de la base applicative créée sur le serveur."
  type        = string
  default     = "appdb"
}

# --- Redis -------------------------------------------------------------------

variable "redis_sku" {
  description = "SKU Azure Managed Redis (redisEnterprise). Balanced_B0 = plus petit."
  type        = string
  default     = "Balanced_B0"
}

# --- Storage -----------------------------------------------------------------

variable "storage_account_tier" {
  description = "Tier du storage account applicatif."
  type        = string
  default     = "Standard"
}

variable "storage_replication" {
  description = "Type de réplication du storage account (non-prod : LRS)."
  type        = string
  default     = "LRS"
}

variable "ci_principal_id" {
  description = "ObjectId du service principal utilisé par GitHub Actions (OIDC). Distinct de l'appId, qui sert à l'authentification."
  type        = string
}