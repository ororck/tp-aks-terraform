# ADR 0003 — Registre d'images

## Statut

Remplace une première version qui retenait GHCR.

## Contexte

Le backend et le frontend sont livrés sous forme d'images de conteneur, poussées
par GitHub Actions et tirées par le cluster AKS mutualisé fourni par le
formateur. Il faut donc un registre, et un mécanisme d'authentification au pull
utilisable depuis un cluster sur lequel nous n'avons que des droits de portée
namespace.

La première version de cet ADR écartait ACR au motif que l'intégration
`az aks update --attach-acr` modifierait le cluster mutualisé. Cette prémisse
est fausse. L'attachement n'est qu'une attribution du rôle `AcrPull` à
l'identité kubelet du cluster, **portée sur le registre**, donc sur une
ressource dont nous sommes propriétaires. Le cluster n'est pas modifié, il est
seulement lu.

## Décision

Un Azure Container Registry est créé dans `msaidiRG` par Terraform. Le rôle
`AcrPull` est attribué à l'identité kubelet du cluster mutualisé, scope registre.
Le service principal de la CI reçoit `AcrPush` sur le même scope.

Le kubelet s'authentifie alors auprès du registre avec son identité managée.
Aucun `imagePullSecret`, aucun jeton à créer, stocker ou renouveler.

## Alternatives écartées

**GHCR en package privé.** Aucune intégration d'identité avec Azure. Impose un
PAT avec `read:packages`, stocké dans un Secret Kubernetes créé hors Terraform,
sans rotation automatique. Un secret de long terme de plus à gérer.

**GHCR en package public.** Fonctionne sans authentification, mais publie
l'image applicative, et ne pouvait se justifier que par l'impossibilité
supposée d'utiliser ACR.

## Conséquences

Le registre ajoute une ressource et un coût au projet, là où GHCR était inclus
dans le compte GitHub.

Le SKU Basic ne permet pas de filtrage réseau, réservé au Premium. Le registre
reste donc joignable publiquement et sa protection repose uniquement sur le
RBAC, contrairement aux autres services managés du projet (voir ADR 0001).

L'identité kubelet appartient au cluster mutualisé, pas à nous. Tout pod du
cluster peut donc tirer nos images, y compris ceux d'un autre apprenant. Même
limite partagée que celle assumée dans l'ADR 0001, avec la même contrepartie :
les images ne contiennent aucun secret, ceux-ci sont injectés au déploiement
depuis le Key Vault.