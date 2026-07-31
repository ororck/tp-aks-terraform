locals {
  # Tags obligatoires : identifient les ressources sans ambiguïté dans la
  # subscription partagée et permettent la découverte par tags dans la CI.
  # component est surchargé par ressource via merge().
  common_tags = {
    owner      = var.owner
    project    = "tp-aks-terraform"
    managed-by = "terraform"
    env        = "nonprod"
  }

  # Nom court sans tirets pour les ressources à contrainte stricte
  # (storage account : 3-24 car, minuscules, alphanumérique uniquement).
  owner_slug = replace(var.owner, "-", "")

  # IP de sortie (egress) du cluster : dans le node RG, l'IP d'entrée de
  # l'ingress porte le préfixe "kubernetes-", l'IP de sortie a un nom en GUID.
  # On exclut donc le préfixe pour isoler l'egress.
  cluster_egress_ip = [
    for ip in data.azurerm_public_ips.cluster.public_ips :
    ip.ip_address if !startswith(ip.name, "kubernetes-")
  ][0]
}
