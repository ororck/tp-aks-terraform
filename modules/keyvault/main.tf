# Récupère l'IP publique de l'exécutant Terraform (ta machine en local, le
# runner GitHub en CI). Elle est autorisée sur le firewall du vault le temps
# d'écrire les secrets, sans jamais ouvrir le vault au public.
data "http" "deployer_ip" {
  url = "https://api.ipify.org"
}

# Key Vault en mode RBAC : les accès aux secrets se gèrent par rôles Azure
# (Key Vault Secrets Officer / User), pas par access policies.
resource "azurerm_key_vault" "this" {
  name                = "kv-${var.owner}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id
  sku_name            = "standard"

  rbac_authorization_enabled = true
  purge_protection_enabled   = false
  soft_delete_retention_days = 7

  # accessible uniquement depuis le backend (IP de sortie du cluster).
  # L'IP de l'exécutant est ajoutée pour permettre à Terraform
  # d'écrire les secrets (RBAC seul ne suffit pas : le pare-feu réseau bloque
  # aussi les appels data-plane, y compris ceux du service principal).
  network_acls {
    default_action = "Deny"
    bypass         = "None"
    ip_rules = [
      var.cluster_egress_ip,
      chomp(data.http.deployer_ip.response_body),
    ]
  }

  tags = merge(var.tags, { component = "keyvault" })
}

# L'exécutant Terraform doit pouvoir écrire les secrets (mot de passe DB, etc.).
resource "azurerm_role_assignment" "tf_officer" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.deployer_principal_id
}

# Le service principal de la CI lit les secrets pour construire le Secret Kubernetes consommé par le backend (ADR 0002).
# Lecture seule : l'écriture reste réservée à l'exécutant Terraform.
resource "azurerm_role_assignment" "ci_reader" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.ci_principal_id
}
