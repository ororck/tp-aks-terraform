# ADR 0002 - Lecture des secrets Key Vault par le backend

## Contexte
Les identifiants PostgreSQL et la clé Redis sont stockés dans Key Vault. Le
backend Spring Boot doit les consommer à l'exécution sans qu'ils soient écrits
en dur ni committés.

## Décision
La CI (déjà authentifiée en OIDC vers Azure) lit les secrets Key Vault et crée
un Secret Kubernetes dans le namespace, que le Deployment backend monte en
variables d'environnement.

## Alternatives écartées
- **Workload Identity + CSI Secrets Store driver.** Le pod obtiendrait sa
  propre identité Entra et lirait Key Vault directement, secrets montés en
  volume avec rotation. C'est l'état de l'art. Écartée car le cluster mutualisé
  n'a ni Workload Identity ni le driver CSI activés (vérifié :
  `securityProfile.workloadIdentity` et `azureKeyvaultSecretsProvider` à null).

## Conséquences
- Le secret est copié dans etcd du cluster ; une rotation demande un
  redéploiement (recréation du Secret par la CI).
- Aucune dépendance à des fonctionnalités du cluster mutualisé que nous ne
  contrôlons pas.
- Si Workload Identity était activé, migrer vers CSI supprimerait la copie du
  secret dans le cluster.
