# ADR 0004 — Accès de la CI aux services managés filtrés par IP

## Contexte

Le Key Vault et le Storage Account sont en `default_action = "Deny"`, avec pour
seules IP autorisées celle de sortie du cluster et celle de l'exécutant
Terraform (voir ADR 0001).

Le pipeline de déploiement doit pourtant les joindre sur leur plan de données :
il lit les secrets du Key Vault pour construire le Secret Kubernetes (ADR 0002),
et génère un User Delegation SAS sur le Storage, le pod n'ayant aucune identité
Azure pour le demander lui-même. Or les runners GitHub sortent d'IP dynamiques,
non connues à l'avance.

## Décision

Le workflow récupère l'IP publique du runner en début de job, l'ajoute au
firewall des deux ressources, fait son travail, puis la retire dans une étape
`if: always()`.

La modification des règles réseau est une opération du plan de contrôle ARM.
Elle n'est donc pas soumise au firewall du plan de données, et le service
principal de la CI peut l'effectuer avec son rôle `Contributor` sur le
resource group.

Aucun `ignore_changes` n'est posé sur les `ip_rules`. L'ouverture étant
refermée à la fin du job, l'état au repos correspond exactement à ce que
Terraform décrit, et il n'y a pas de dérive à absorber.

## Alternatives écartées

**Autoriser les plages d'IP des runners GitHub.** GitHub déconseille
explicitement cet usage. La liste publiée compte des milliers de blocs CIDR,
évolue régulièrement, et dépasse la limite de 1000 règles IPv4 du Key Vault.
Des runners sortant d'IP hors des plages publiées ont par ailleurs été
constatés.

**Passer `default_action` à `Allow`.** Fait échouer le scan tfsec exigé en CI,
qui vérifie que la network ACL du Key Vault est bien en `Deny`, et vide l'ADR
0001 de sa substance.

**Runner self-hosted dans le cluster.** L'IP de sortie serait déjà autorisée,
mais cela ajoute un composant permanent à maintenir sur un cluster mutualisé
que nous ne contrôlons pas.

**Larger runners à IP statique.** Payant et réservé à GitHub Enterprise Cloud.

## Conséquences

Le firewall des deux ressources est ouvert à une IP publique partagée pendant
la durée du job, quelques minutes. La défense repose sur le RBAC durant cette
fenêtre, dans la même logique que la limite déjà assumée en ADR 0001.

Un `terraform apply` lancé pendant qu'un pipeline tourne effacerait l'IP du
runner en cours de job et le ferait échouer. En non-prod, avec un seul
opérateur, le risque est accepté.

Une propagation de quelques secondes existe entre l'ajout de la règle et sa
prise en compte côté plan de données, d'où l'attente explicite dans le
workflow avant le premier appel.