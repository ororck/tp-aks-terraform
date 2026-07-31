# ADR 0003 - Registre d'images conteneur

## Statut
Accepté

## Contexte
Le cahier des charges ne fournit pas de registre. Le cluster AKS doit tirer les
images du backend et du frontend depuis un registre accessible.

## Décision
Utiliser **GitHub Container Registry (GHCR)**. Les images sont poussées par
GitHub Actions avec le `GITHUB_TOKEN`, et le cluster les tire via un
`imagePullSecret` (PAT en lecture) posé dans le namespace.

## Alternatives écartées
- **Azure Container Registry (ACR) dans le RG dédié.** Plus "Azure natif",
  mais l'intégration propre (`az aks update --attach-acr`) modifie le cluster
  mutualisé, ce qui n'est pas autorisé. Il faudrait de toute façon un
  imagePullSecret. GHCR est retenu pour sa simplicité et sa cohérence avec le
  choix GitHub Actions.

## Conséquences
- Un `imagePullSecret` (PAT read:packages) est géré dans le namespace.
- Le registre vit hors d'Azure : cohérent avec un pipeline centré sur GitHub.
- Pas de coût ni de ressource ACR à provisionner.
