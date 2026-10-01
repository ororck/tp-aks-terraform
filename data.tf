# Ressources FOURNIES, référencées et non créées.

# resource group dédié.
data "azurerm_resource_group" "dedicated" {
  name = var.resource_group_name
}

# cluster AKS mutualisé (fourni par le formateur).
# cluster en Entra ID + Azure RBAC.
data "azurerm_kubernetes_cluster" "shared" {
  name                = var.aks_name
  resource_group_name = var.aks_resource_group
}

# Identité courante (pour s'attribuer les droits data-plane Key Vault).
data "azurerm_client_config" "current" {}

# IP de sortie (egress) du cluster, résolue automatiquement depuis le loadBalancer AKS.
data "azurerm_public_ips" "cluster" {
  resource_group_name = data.azurerm_kubernetes_cluster.shared.node_resource_group
}
# IP d'entrée de l'ingress managé (add-on Application Routing) : l'IP publique
# du node RG portant le tag posé par AKS pour le Service app-routing-system/nginx.
# Le cluster ayant déjà vu son IP changer, aucune valeur n'est figée.
data "azurerm_resources" "ingress_ip" {
  resource_group_name = data.azurerm_kubernetes_cluster.shared.node_resource_group
  type                = "Microsoft.Network/publicIPAddresses"

  required_tags = {
    "k8s-azure-service" = "app-routing-system/nginx"
  }
}

data "azurerm_public_ip" "ingress" {
  name                = data.azurerm_resources.ingress_ip.resources[0].name
  resource_group_name = data.azurerm_kubernetes_cluster.shared.node_resource_group
}
