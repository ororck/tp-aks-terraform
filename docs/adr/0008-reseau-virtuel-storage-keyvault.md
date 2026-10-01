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
le subnet. Le droit est attribué à la CI **sur le seul subnet `aks-subnet`**
(jamais sur le VNet ni le node RG) et figure dans `scripts/oidc.sh`.

## Alternatives écartées

**Rôle custom limité à cette seule action.** C'est le moindre privilège
strict, mais impossible : créer une définition de rôle exige
`Microsoft.Authorization/roleDefinitions/write`, que nous n'avons pas sur
l'abonnement partagé (tentative refusée, AuthorizationFailed).

**Rôle built-in détourné de son domaine** (par exemple `DocumentDB Account
Contributor`, qui porte aussi cette action). Écarté : attribuer un rôle Cosmos
DB pour une règle de réseau est incohérent, et indéfendable en audit même si
l'effet réel à cette portée serait identique.

## Pourquoi Network Contributor sur le subnet

`Network Contributor` est le built-in dont le domaine est précisément le
réseau, et qui porte légitimement `joinViaServiceEndpoint`. Il est large en
soi (il gère les ressources réseau), mais la portée le borne : attribué sur un
seul subnet, il ne donne aucun droit sur le reste du VNet, sur les autres
subnets, ni sur les ressources des autres apprenants. Le moindre privilège est
tenu par la portée, faute de pouvoir le tenir par la définition du rôle.

## Statut

Appliqué : code Terraform (modules storage et keyvault, data subnet) et
attribution du rôle sur le subnet.
