# ADR 0005 : Découverte des ressources par tags

## Contexte

Les pipelines applicatifs ont besoin du Key Vault, du registre, du storage, de
PostgreSQL et de Redis. Coder leurs noms dans chaque workflow duplique une
information que Terraform détient déjà, et casse dès qu'un nom change.

## Décision

Toute ressource créée par Terraform porte les tags `owner`, `project`,
`managed-by`, `env` et `component` (locals.tf, complété par `component` dans
chaque module). La CI retrouve ses ressources par une requête sur le tag
`owner` dans le resource group dédié (`az keyvault list --query
"[?tags.owner=='...']"`), puis par `component` pour distinguer les types.

## Exception

Le cluster AKS et son node resource group appartiennent au formateur. Ils ne
peuvent pas être tagués par nous (cluster mutualisé en lecture seule). Ils
restent donc référencés par nom (`aks-nonprod-prf2026`, `rg-shared-prf2026`),
en variables Terraform et en entrées de workflow.

## Alternatives écartées

**Noms codés en dur dans les workflows.** Simple, mais duplique la source de
vérité et échoue en silence quand un nom dérive.

**Outputs Terraform lus depuis le state.** Exige que la CI applicative ait
accès au state, ce qui élargit ses droits sans nécessité.

## Conséquences

Un tag manquant rend une ressource invisible pour la CI. Le contrôle de drift
vérifie donc l'étiquetage de chaque ressource créée.
