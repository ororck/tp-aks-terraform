markdown
# Infrastructure non-prod - TP IaC Azure (cible AKS)

Provisionne l'infrastructure de l'environnement non-production sur la
subscription Simplon : base PostgreSQL, cache Managed Redis, Storage Account,
Key Vault, Container Registry, et le namespace applicatif (avec ses
NetworkPolicies) dans le cluster AKS mutualisé.

## Architecture

Le cluster AKS et le resource group dédié sont **fournis** : ce Terraform les
référence en `data` et ne gère que les ressources propres à l'environnement.

> Schéma d'architecture : `docs/architecture.drawio` (source) et
> `docs/architecture.png` (rendu).

```
Internet
   |
   v
Ingress managé (app-routing-system, 20.74.93.53)   [FOURNI]
   |
   v
[ namespace mohamed-saidi ]        [CRÉÉ ICI]
   frontend (Service, nginx)  --->  backend (Service ClusterIP)
        ^ NetworkPolicy :                ^ NetworkPolicy :
          ingress-controller only          pods frontend only
                                        |
                    +-------------------+-------------------+
                    v                   v                   v
              PostgreSQL            Managed Redis      Key Vault / Storage
              (firewall IP          (clé en KV)        (network ACL IP egress)
               egress cluster)

ACR (acrmohamedsaidi)  --->  images tirées par l'identité kubelet du cluster
```

Le frontend est le seul composant exposé. Le backend est en ClusterIP et n'est
joignable que par le reverse proxy nginx du frontend, sur `/api/`. Les services
managés sont réservés au backend via un filtrage sur l'**IP de sortie du
cluster**, résolue automatiquement depuis le node resource group.

L'ACR fait exception : le SKU Basic ne permet pas de filtrage réseau, sa
protection repose uniquement sur le RBAC. Voir ADR 0003.

## Structure

```
.
├── backend.tf          # state distant azurerm (voir Bootstrap)
├── providers.tf        # azurerm + kubernetes + random + http
├── data.tf             # RG dédié, cluster AKS, IP publiques du node RG
├── variables.tf        # variables racine (détaillées)
├── locals.tf           # tags communs, slug, IP egress du cluster
├── main.tf             # câblage des modules
├── outputs.tf
├── docs/adr/           # journal des décisions d'architecture (0001 à 0004)
├── scripts/            # bootstrap (voir ci-dessous)
└── modules/
    ├── keyvault/       # Key Vault RBAC + rôles Secrets Officer et CI
    ├── postgres/       # Flexible Server + secrets écrits en KV
    ├── redis/          # Managed Redis + clé en KV
    ├── storage/        # Storage Account réseau restreint + rôle CI
    ├── acr/            # Container Registry + AcrPull kubelet, AcrPush CI
    └── kubernetes/     # namespace + NetworkPolicies (section 6)
```

Chaque module expose `main.tf` / `variables.tf` (déclarations simples) /
`outputs.tf`. Les variables sont détaillées à la racine.

## Prérequis

**Outils** : Terraform >= 1.7, Azure CLI, et `kubelogin`. Ce dernier est
indispensable : le cluster est en Entra ID + Azure RBAC, donc `kube_config` ne
fournit aucun credential statique et le provider kubernetes s'authentifie via
un bloc `exec` appelant `kubelogin`.

```bash
az aks install-cli
export PATH="$PATH:$HOME/.azure-kubectl:$HOME/.azure-kubelogin"
```

**Rôles Azure** : le compte exécutant doit pouvoir créer des attributions de
rôle (`Role Based Access Control Administrator` ou équivalent) et disposer de
`Storage Blob Data Contributor` sur le storage du state, sinon `terraform init`
échoue en 403.

**Bootstrap** : le storage account du state ne peut pas être créé par le
Terraform qui l'utilise comme backend. Les scripts de `scripts/` le
provisionnent en amont, ainsi que l'app registration OIDC de la CI :

```bash
./scripts/run-all.sh    # providers.sh + state-backend.sh + oidc.sh
```

Renseigner ensuite `backend.tf` avec le nom du storage account généré.

## Utilisation

```bash
# 1. Config : ci_principal_id est la seule variable sans valeur par défaut.
#    C'est l'ObjectId du service principal de la CI, affiché par oidc.sh.
#    À ne pas confondre avec l'appId, qui sert à l'authentification.
cat > terraform.tfvars <<'EOF'
ci_principal_id = "<object-id-du-service-principal>"
EOF

# 2. Déploiement
terraform init
terraform plan
terraform apply
```

L'IP de sortie du cluster n'est plus à renseigner : elle est résolue
automatiquement dans `locals.tf`, en filtrant les IP publiques du node resource
group (l'IP d'entrée de l'ingress porte le préfixe `kubernetes-`, celle de
sortie a un nom en GUID).

En CI, l'`apply` se déclenche manuellement :

```bash
gh workflow run terraform.yml
```

## Sécurité

- State distant chiffré (Azure Storage, auth Entra ID).
- Aucun secret en dur : le mot de passe PostgreSQL est généré
  (`random_password`) et écrit dans Key Vault ; `terraform.tfvars` est
  git-ignoré.
- Toutes les ressources sont taguées `owner` + `component` (+ project, env),
  ce qui permet leur découverte par tags dans la CI (pas de nom codé en dur).
- Key Vault et Storage sont en `default_action = "Deny"`. Les runners GitHub
  ayant des IP dynamiques, les pipelines applicatifs ouvrent puis referment
  leur IP le temps du job. Voir ADR 0004.
- Le cluster tire ses images via l'identité kubelet, sans `imagePullSecret` ni
  jeton stocké. Voir ADR 0003.

## Décisions d'architecture

- **ADR 0001** — isolation réseau des services managés
- **ADR 0002** — lecture des secrets Key Vault par le backend
- **ADR 0003** — registre d'images
- **ADR 0004** — accès de la CI aux services filtrés par IP