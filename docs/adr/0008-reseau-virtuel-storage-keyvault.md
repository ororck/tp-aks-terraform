# ADR 0008 : Règles de réseau virtuel sur le storage et le Key Vault

## Contexte

L'ADR 0001 filtrait le storage et le Key Vault par IP de sortie du cluster.
Le backend déployé reçoit pourtant un 403 `AuthorizationFailure` du storage,
alors que l'IP d'egress figure dans les règles. Le cluster et le storage sont
dans la même région : les règles IP du pare-feu Storage ne s'appliquent pas au
trafic issu de la même région, dont la source reste une adresse privée du VNet.

## Décision

Le subnet des nœuds (`aks-subnet`) porte déjà les service endpoints
`Microsoft.Storage` et `Microsoft.KeyVault`. Le storage et le Key Vault
l'autorisent en plus des IP (`virtual_network_subnet_ids`). Le subnet est
résolu dynamiquement (VNet retrouvé par type dans le node RG, subnet par nom).
Les règles IP restent : elles servent aux exécutants CI et à PostgreSQL, qui
n'est pas concerné (accès public filtré par IP).

## Droit requis

Ajouter une règle de réseau virtuel exige
`Microsoft.Network/virtualNetworks/subnets/joinViaServiceEndpoint/action` sur
le subnet. Le droit doit être attribué à la CI sur ce seul subnet, jamais sur
le VNet ni le node RG, et figurer dans `scripts/oidc.sh`.

## Statut

Code Terraform écrit. Droit de jointure de la CI : en attente (création d'un
rôle custom refusée par les permissions, voir la décision en cours).
