# ADR 0001 - Isolation réseau des services managés

## Statut
Accepté

## Contexte
La section 6 exige que PostgreSQL, Storage et Key Vault soient accessibles
uniquement depuis le backend. Le cluster AKS est mutualisé : son VNet
appartient au formateur et est partagé entre tous les apprenants.

## Décision
Filtrage réseau par **IP de sortie du cluster** : chaque service managé refuse
tout trafic par défaut et n'autorise que l'IP publique d'egress du cluster
(firewall PostgreSQL, network ACL Storage et Key Vault).

## Alternatives écartées
- **Private endpoints + private DNS dans le VNet du cluster.** C'est
  l'isolation réseau réelle et la solution cible en entreprise. Écartée car
  elle exige des droits Owner/Contributor sur le VNet mutualisé (création de
  subnet et d'endpoints), droits que nous n'avons pas sur un cluster partagé.

## Conséquences
- L'accès aux services managés est restreint au niveau IP, pas au niveau
  identité ou pod.
- Limite assumée : l'IP de sortie est partagée par tous les pods du cluster
  mutualisé. Un pod d'un autre apprenant passerait donc le firewall réseau.
  La défense complémentaire repose sur : Key Vault en RBAC (seule l'identité
  autorisée lit les secrets), PostgreSQL protégé par identifiants stockés en
  Key Vault, et NetworkPolicies internes au namespace.
- Si le formateur accorde un accès au VNet, migrer vers des private endpoints
  supprime cette limite.
