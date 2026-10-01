# ADR 0006 : Droit cluster-scope de la CI

## Contexte

Le namespace `mohamed-saidi` est créé par Terraform. Créer un namespace est
une opération de portée cluster, alors que les droits du rôle `Azure
Kubernetes Service RBAC Writer` s'arrêtent au niveau namespace. Le cluster est
mutualisé : accorder plus que nécessaire expose les namespaces des autres
apprenants.

## Décision

Un ClusterRole Kubernetes custom (`k8s/ci-namespace-clusterrole.yaml`) est lié
à l'identité de la CI. Il autorise `create` sur les namespaces (impossible à
restreindre par nom, l'objet n'existe pas encore) et `get`, `update`, `patch`,
`delete` uniquement sur le namespace `mohamed-saidi` via `resourceNames`.

Le manifest est écrit dans le dépôt mais **appliqué par un administrateur du
cluster**, car nous n'avons aucun droit pour créer un ClusterRole sur un
cluster mutualisé.

## Alternatives écartées

**`Azure Kubernetes Service RBAC Cluster Admin`.** Trop large : droits
complets sur tous les namespaces de la promotion.

**Namespace créé par le formateur.** Ferme le besoin mais retire la création du
namespace du périmètre Terraform, et donc de la reproductibilité.

## Repli

Si l'application du ClusterRole reste bloquée après une tentative sérieuse, le
repli est `AKS RBAC Cluster Admin` sur le cluster. Ce compromis sera consigné
ici avec la date et la raison si nous devons l'utiliser.

## Complément : droits dans le namespace

Le ClusterRole ne couvre que l'objet namespace. Une fois celui-ci créé, la CI
reçoit un 403 sur les objets qu'il contient (NetworkPolicies, puis les
ressources des pipelines de déploiement). Un Role et un RoleBinding limités au
namespace `mohamed-saidi` (`k8s/ci-namespace-role.yaml`) comblent ce manque,
sans élargir les droits aux autres namespaces. Application par un
administrateur du cluster.

## Statut

ClusterRole appliqué par un administrateur. Role de namespace écrit, à appliquer.
