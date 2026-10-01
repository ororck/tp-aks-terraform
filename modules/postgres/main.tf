# Mot de passe admin généré : jamais écrit en dur ni committé.
resource "random_password" "admin" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "azurerm_postgresql_flexible_server" "this" {
  name                = "psql-${var.owner}"
  location            = var.location
  resource_group_name = var.resource_group_name

  version                = var.postgres_version
  sku_name               = var.postgres_sku
  storage_mb             = var.postgres_storage_mb
  administrator_login    = var.admin_login
  administrator_password = random_password.admin.result

  # Non-prod : pas de haute dispo, pas de zone forcée.
  zone = "1"

  # Accès public activé mais verrouillé par firewall (règles ci-dessous).
  # Nécessaire : sans VNet dédié (cluster mutualisé), le private access n'est
  # pas une option. Section 6 : seules les IP autorisées passent.
  public_network_access_enabled = true

  tags = merge(var.tags, { component = "postgres" })

  lifecycle {
    ignore_changes = [zone] # évite un diff si Azure réassigne la zone
  }
}

# Firewall : IP de sortie du cluster (le backend à l'exécution).
resource "azurerm_postgresql_flexible_server_firewall_rule" "cluster" {
  name             = "allow-cluster-egress"
  server_id        = azurerm_postgresql_flexible_server.this.id
  start_ip_address = var.cluster_egress_ip
  end_ip_address   = var.cluster_egress_ip
}

# Firewall : IP de l'exécutant Terraform (création de la base, gestion). L'IP
# vient de var.deployer_ip, fournie par la CI : aucun appel externe pendant le
# plan, et aucune règle en local si la variable est vide.
resource "azurerm_postgresql_flexible_server_firewall_rule" "deployer" {
  count            = var.deployer_ip == "" ? 0 : 1
  name             = "allow-deployer"
  server_id        = azurerm_postgresql_flexible_server.this.id
  start_ip_address = var.deployer_ip
  end_ip_address   = var.deployer_ip
}

# Base applicative.
resource "azurerm_postgresql_flexible_server_database" "app" {
  name      = var.database_name
  server_id = azurerm_postgresql_flexible_server.this.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

# --- Secrets écrits dans Key Vault (rien en clair ailleurs) ------------------
# Pas d'expiration : aucun mécanisme de rotation, une date d'expiration
# casserait l'application. content_type non renseigné, secrets à usage unique.
#trivy:ignore:AVD-AZU-0017
#trivy:ignore:AVD-AZU-0015
resource "azurerm_key_vault_secret" "host" {
  name         = "postgres-host"
  value        = azurerm_postgresql_flexible_server.this.fqdn
  key_vault_id = var.key_vault_id
}
#trivy:ignore:AVD-AZU-0017
#trivy:ignore:AVD-AZU-0015
resource "azurerm_key_vault_secret" "user" {
  name         = "postgres-user"
  value        = var.admin_login
  key_vault_id = var.key_vault_id
}
#trivy:ignore:AVD-AZU-0017
#trivy:ignore:AVD-AZU-0015
resource "azurerm_key_vault_secret" "password" {
  name         = "postgres-password"
  value        = random_password.admin.result
  key_vault_id = var.key_vault_id
}
