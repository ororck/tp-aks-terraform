# ADR 0007 : Report de la migration azurerm 5.x et kubernetes 3.x

## Contexte

Dependabot propose `hashicorp/azurerm` de `~> 4.0` vers `~> 5.6` et
`hashicorp/kubernetes` de `~> 2.32` vers `~> 3.2`. Les deux sont des versions
majeures.

azurerm 5.0 change l'enregistrement des Resource Providers, supprime
`skip_provider_registration` du bloc provider et renomme des champs de
ressources que le projet utilise : `azurerm_key_vault`, `azurerm_container_registry`,
`azurerm_kubernetes_cluster` (data source) et `azurerm_storage_account`.

Le provider kubernetes 3.x n'a pas été validé avec l'authentification par bloc
`exec` et `kubelogin` utilisée sur ce cluster Entra ID.

## Décision

Rester sur `~> 4.0` et `~> 2.32`. Les PR Dependabot correspondantes sont
fermées avec cette justification. La migration sera traitée dans un travail
dédié, avec un `terraform plan` complet, après la fin du TP.

## Conséquences

La dépendance n'est pas à jour au sens strict. Le risque est accepté : les
versions 4.x et 2.x restent maintenues, et une migration majeure à la veille
du déploiement ferait porter un risque d'échec sur les ressources que nous ne
pouvons recréer que dans une souscription au crédit limité.
