# Key Vault en mode RBAC : les accès aux secrets se gèrent par rôles Azure
# (Key Vault Secrets Officer / User), pas par access policies.

# Non-prod assumé : la purge protection empêcherait de recréer le vault sous le
# même nom après un destroy.
#trivy:ignore:AVD-AZU-0016
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
  # L'IP de l'exécutant (var.deployer_ip, fournie par la CI) est ajoutée
  # pour permettre à Terraform d'écrire les secrets (RBAC seul ne suffit pas : le pare-feu réseau bloque
  # aussi les appels data-plane, y compris ceux du service principal).
  network_acls {
    default_action = "Deny"
    bypass         = "None"
    ip_rules       = compact([var.cluster_egress_ip, var.deployer_ip])
    # Même raison que pour le storage (ADR 0008).
    virtual_network_subnet_ids = [var.aks_subnet_id]
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
