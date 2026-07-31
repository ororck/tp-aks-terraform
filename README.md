# Infrastructure non-prod - TP IaC Azure (cible AKS)

Provisionne l'infrastructure de l'environnement non-production sur la
subscription Simplon : base PostgreSQL, cache Managed Redis, Storage Account,
Key Vault, et le namespace applicatif (avec ses NetworkPolicies) dans le
cluster AKS mutualisé.

## Architecture

Le cluster AKS et le resource group dédié sont **fournis** : ce Terraform les
référence en `data` et ne gère que les ressources propres à l'environnement.

```
Internet
   |
   v
Ingress managé (app-routing-system, IP publique)   [FOURNI]
   |
   v
[ namespace mohamed-saidi ]        [CRÉÉ ICI]
   frontend (Service)  --->  backend (Service ClusterIP)
        ^ NetworkPolicy              ^ NetworkPolicy: frontend uniquement
        ingress-controller only
                                        |
                    +-------------------+-------------------+
                    v                   v                   v
              PostgreSQL            Managed Redis      Key Vault / Storage
              (firewall IP          (clé en KV)        (network ACL IP egress)
               egress cluster)
```

Toutes les ressources managées créées sont réservées au backend via un
filtrage sur l'**IP de sortie du cluster**. Voir l'ADR pour les limites de ce
choix.

## Structure

```
.
├── backend.tf          # state distant azurerm (voir Bootstrap)
├── providers.tf        # azurerm + kubernetes + random
├── data.tf             # RG dédié + cluster AKS (existants)
├── variables.tf        # variables racine (détaillées)
├── locals.tf           # tags communs, slug
├── main.tf             # câblage des modules
├── outputs.tf
└── modules/
    ├── keyvault/       # Key Vault RBAC + rôle Secrets Officer
    ├── postgres/       # Flexible Server + secrets écrits en KV
    ├── redis/          # Managed Redis + clé en KV
    ├── storage/        # Storage Account réseau restreint
    └── kubernetes/     # namespace + NetworkPolicies (section 6)
```

Chaque module expose `main.tf` / `variables.tf` (déclarations simples) /
`outputs.tf`. Les variables sont détaillées à la racine.

## Prérequis (bootstrap manuel)

Le storage account du state ne peut pas être créé par le Terraform qui
l'utilise comme backend. Il est provisionné en amont par `bootstrap.sh`
(hors de ce dépôt), avec l'app registration OIDC de la CI. Renseigner ensuite
`backend.tf` avec le nom du storage account généré.

## Utilisation

```bash
# 1. Relever l'IP de sortie du cluster
kubectl run egress-check --rm -it --restart=Never -n mohamed-saidi \
  --image=curlimages/curl -- curl -s ifconfig.me

# 2. Config
cp terraform.tfvars.example terraform.tfvars   # renseigner cluster_egress_ip

# 3. Déploiement
terraform init
terraform plan
terraform apply
```

## Sécurité

- State distant chiffré (Azure Storage, auth Entra ID).
- Aucun secret en dur : le mot de passe PostgreSQL est généré (`random_password`)
  et écrit dans Key Vault ; `terraform.tfvars` est git-ignoré.
- Toutes les ressources sont taguées `owner` + `component` (+ project, env),
  ce qui permet leur découverte par tags dans la CI (pas de nom codé en dur).

## Points ouverts

- Namespace : créé par ce Terraform. Confirmer avec le formateur que chacun
  crée le sien (droit RBAC cluster nécessaire).
- Isolation réseau : voir ADR 0001.
