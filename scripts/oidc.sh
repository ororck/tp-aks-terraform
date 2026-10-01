#!/usr/bin/env bash
# Identité OIDC de GitHub Actions : app registration, service principal,
# rôles d'amorçage (portée la plus étroite possible) et federated credentials
# des 3 dépôts. Idempotent. Toute attribution de rôle de la CI figure ici.
#
# Les dépôts créés après le 15/07/2026 émettent un subject immuable :
#   repo:<owner>@<owner_id>/<repo>@<repo_id>:<contexte>
# Les identifiants numériques sont lus via l'API GitHub, jamais codés en dur.
set -euo pipefail

SUBSCRIPTION_ID="5e683e0f-b00c-48d6-9769-5aaf598de8f1"
RG_NAME="msaidiRG"
AKS_RG="rg-shared-prf2026"
AKS_NAME="aks-nonprod-prf2026"
NODE_RG="MC_${AKS_RG}_${AKS_NAME}_francecentral"
APP_NAME="gh-tp-aks-mohamed-saidi"
GH_ORG="ororck"
GH_REPOS=("tp-aks-terraform" "tp-aks-backend" "tp-aks-frontend")

az account set --subscription "$SUBSCRIPTION_ID"
SUB_SCOPE="/subscriptions/${SUBSCRIPTION_ID}"
RG_SCOPE="${SUB_SCOPE}/resourceGroups/${RG_NAME}"
AKS_SCOPE="${SUB_SCOPE}/resourceGroups/${AKS_RG}/providers/Microsoft.ContainerService/managedClusters/${AKS_NAME}"
NODE_RG_SCOPE="${SUB_SCOPE}/resourceGroups/${NODE_RG}"

APP_ID=$(az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv)
if [ -z "$APP_ID" ]; then
  APP_ID=$(az ad app create --display-name "$APP_NAME" --query appId -o tsv)
  echo "app creee : $APP_ID"
else
  echo "app existante : $APP_ID"
fi
az ad sp show --id "$APP_ID" &>/dev/null || az ad sp create --id "$APP_ID" >/dev/null
SP_OBJECT_ID=$(az ad sp show --id "$APP_ID" --query id -o tsv)

assign() { # role, scope
  local existing
  existing=$(az role assignment list --assignee "$SP_OBJECT_ID" --role "$1" --scope "$2" \
    --query "[?scope=='$2'] | length(@)" -o tsv)
  if [ "$existing" != "0" ]; then
    echo "$1 sur ${2##*/} : deja present"
  else
    MSYS_NO_PATHCONV=1 az role assignment create \
      --assignee-object-id "$SP_OBJECT_ID" --assignee-principal-type ServicePrincipal \
      --role "$1" --scope "$2" >/dev/null
    echo "$1 sur ${2##*/} : attribue"
  fi
}

# Création et gestion des ressources du projet.
assign "Contributor" "$RG_SCOPE"
# Terraform crée des role assignments (AcrPull, Secrets User, Blob Contributor).
assign "Role Based Access Control Administrator" "$RG_SCOPE"
# Contributor / Key Vault Contributor ne peuvent pas purger un vault (notActions).
assign "Key Vault Purge Operator" "$RG_SCOPE"
# State Terraform lu et écrit en Entra ID (use_azuread_auth) : rôle data-plane
# limité au seul storage account du state, retrouvé par tag.
STATE_SA_ID=$(az storage account list -g "$RG_NAME" \
  --query "[?tags.owner=='mohamed-saidi' && tags.component=='tfstate'].id | [0]" -o tsv)
[ -n "$STATE_SA_ID" ] || { echo "storage du state introuvable : lancer storage-container.sh" >&2; exit 1; }
assign "Storage Blob Data Contributor" "$STATE_SA_ID"
# Cluster mutualisé : lecture seule, aucune modification.
assign "Reader" "$AKS_SCOPE"
assign "Reader" "$NODE_RG_SCOPE"
assign "Azure Kubernetes Service Cluster User Role" "$AKS_SCOPE"

# Règles de réseau virtuel (service endpoints) du storage et du Key Vault :
# les règles IP ne s'appliquent pas au trafic de la même région que le storage.
# La CI doit pouvoir joindre aks-subnet (joinViaServiceEndpoint). Network
# Contributor est le built-in qui porte cette action, attribué sur ce seul
# subnet (VNet géré du node RG), jamais sur le VNet ni le node RG. Voir ADR 0008.
SUBNET_VNET=$(az network vnet list -g "$NODE_RG" --query "[0].name" -o tsv)
SUBNET_SCOPE="${NODE_RG_SCOPE}/providers/Microsoft.Network/virtualNetworks/${SUBNET_VNET}/subnets/aks-subnet"
assign "Network Contributor" "$SUBNET_SCOPE"

# Federated credentials : main (deploiement) et pull_request (checks).
OWNER_ID=$(gh api "users/${GH_ORG}" -q .id)
for REPO in "${GH_REPOS[@]}"; do
  REPO_ID=$(gh api "repos/${GH_ORG}/${REPO}" -q .id)
  PREFIX="repo:${GH_ORG}@${OWNER_ID}/${REPO}@${REPO_ID}"
  for CTX in "main:ref:refs/heads/main" "pr:pull_request"; do
    FC_NAME="gh-${REPO}-${CTX%%:*}"
    SUBJECT="${PREFIX}:${CTX#*:}"
    if az ad app federated-credential list --id "$APP_ID" \
         --query "[?name=='${FC_NAME}']" -o tsv | grep -q "$FC_NAME"; then
      echo "$FC_NAME : deja present"
    else
      az ad app federated-credential create --id "$APP_ID" --parameters "{
        \"name\": \"${FC_NAME}\",
        \"issuer\": \"https://token.actions.githubusercontent.com\",
        \"subject\": \"${SUBJECT}\",
        \"audiences\": [\"api://AzureADTokenExchange\"]
      }" >/dev/null
      echo "$FC_NAME : cree"
    fi
  done
done

TENANT_ID=$(az account show --query tenantId -o tsv)
echo ""
echo ">>> Secrets GitHub (les 3 depots) :"
echo "    AZURE_CLIENT_ID       = $APP_ID"
echo "    AZURE_TENANT_ID       = $TENANT_ID"
echo "    AZURE_SUBSCRIPTION_ID = $SUBSCRIPTION_ID"
echo "    TF_VAR_ci_principal_id = $SP_OBJECT_ID (depot terraform)"
