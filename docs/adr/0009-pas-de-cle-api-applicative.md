# ADR 0009 : Pas de clé d'API applicative entre le front et le backend

## Contexte

Le backend Spring Boot embarque un `ApiKeyFilter` qui exige l'en-tête
`X-Api-Key` sur `/api/**` lorsque `BACKEND_API_KEY` est définie. Sur AKS cette
variable n'est pas injectée : le filtre laisse tout passer, et l'API répond 200
sans clé. Le sujet du TP exige l'isolation réseau, pas une authentification
applicative.

## Décision

Aucune clé d'API applicative. La protection du backend repose sur le réseau :

1. Le Service `backend` est de type `ClusterIP` : il n'a ni IP externe ni route
   depuis l'extérieur du cluster.
2. Le seul chemin public vers lui est `/api/` sur l'Ingress, qui traverse le
   proxy nginx du frontend.
3. La NetworkPolicy `allow-frontend-to-backend` n'autorise vers le backend que
   les pods du frontend du namespace.

Le 200 sans clé est donc un choix assumé et non un défaut. Le placeholder
`__BACKEND_API_KEY__`, l'intercepteur Angular et l'argument de build `API_KEY`
du frontend sont supprimés.

## Alternative écartée

**Injecter la clé** (secret Key Vault, variable `BACKEND_API_KEY` côté backend,
substitution dans le bundle du front). Écartée car une application Angular est
servie au navigateur : la clé serait lisible par n'importe quel visiteur dans le
JavaScript. Elle ne protégerait donc rien de plus que le réseau, tout en
ajoutant un secret à créer, à injecter et à faire tourner.

## Conséquences

- Quiconque atteint le proxy nginx atteint l'API : c'est le périmètre voulu
  d'une application publique sans compte.
- La limite réelle est celle de l'ADR 0001 : les pods des autres apprenants du
  cluster mutualisé ne sont filtrés que par les NetworkPolicies du namespace.
- `scripts/smoke-test.sh` vérifie l'isolation réseau (Service ClusterIP et
  absence de route directe vers le backend) au lieu d'un refus 401.
- Si une authentification devient exigée, il faudrait un vrai mécanisme
  (jeton utilisateur, Entra ID), pas une clé partagée.
