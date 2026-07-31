# SKU Basic : suffisant en non-prod. À noter, le filtrage réseau n'existe
# qu'en Premium, donc l'ACR reste joignable publiquement et sa protection
# repose entièrement sur le RBAC, contrairement aux autres services (ADR 0001).
resource "azurerm_container_registry" "this" {
  name                = "acr${var.owner_slug}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Basic"
  admin_enabled       = false

  tags = merge(var.tags, { component = "acr" })
}

# Équivalent exact de `az aks update --attach-acr` : l'attachement n'est qu'une
# attribution de rôle portée sur le registre. Le cluster mutualisé n'est pas
# modifié, on ne fait que lire son identité kubelet. Voir ADR 0003.
resource "azurerm_role_assignment" "kubelet_pull" {
  scope                = azurerm_container_registry.this.id
  role_definition_name = "AcrPull"
  principal_id         = var.kubelet_principal_id
}

# La CI pousse les images du backend et du frontend.
resource "azurerm_role_assignment" "ci_push" {
  scope                = azurerm_container_registry.this.id
  role_definition_name = "AcrPush"
  principal_id         = var.ci_principal_id
}