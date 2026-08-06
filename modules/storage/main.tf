# IP publique de l'exécutant Terraform, autorisée le temps de créer le
# container (sinon le firewall du storage bloque aussi l'exécutant).
# ATTENTION : ip_rules du storage refuse une IP en /32. On passe l'IP nue.
data "http" "deployer_ip" {
  url = "https://api.ipify.org"
}

resource "azurerm_storage_account" "this" {
  name                = "st${var.owner_slug}"
  location            = var.location
  resource_group_name = var.resource_group_name

  account_tier             = var.account_tier
  account_replication_type = var.replication
  account_kind             = "StorageV2"

  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false

  # Accessible uniquement depuis le backend (IP du cluster).
  # L'IP de l'exécutant est ajoutée pour créer le container. bypass est une
  # LISTE ici (différent du Key Vault). ip_rules attend des IP nues (pas /32).
  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
    ip_rules = [
      var.cluster_egress_ip,
      chomp(data.http.deployer_ip.response_body),
    ]
  }

  tags = merge(var.tags, { component = "storage" })
}

# Container applicatif.
resource "azurerm_storage_container" "app" {
  name                  = "app-data"
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "private"
}

# La CI génère un User Delegation SAS à chaque déploiement (profil aks du
# backend). L'opération exige un rôle data-plane sur le storage, le
# Contributor du plan de contrôle ne suffit pas.
resource "azurerm_role_assignment" "ci_blob" {
  scope                = azurerm_storage_account.this.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.ci_principal_id
}
