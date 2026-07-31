#!/usr/bin/env bash
# Cree l'identite OIDC pour GitHub Actions : app registration, service
# principal, role Contributor sur le RG dedie, et federated credentials
# pour les 3 depots. Idempotent.
set -euo pipefail

SUBSCRIPTION_ID="5e683e0f-b00c-48d6-9769-5aaf598de8f1"
RG_NAME="msaidiRG"
APP_NAME="gh-tp-aks-mohamed-saidi"
GH_ORG="ororck"
GH_REPOS=("tp-aks-terraform" "tp-aks-backend" "tp-aks-frontend")

az account set --subscription "$SUBSCRIPTION_ID"

# App registration + service principal
APP_ID=$(az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv)
if [ -z "$APP_ID" ]; then
  APP_ID=$(az ad app create --display-name "$APP_NAME" --query appId -o tsv)
  echo "app creee : $APP_ID"
else
  echo "app existante : $APP_ID"
fi
az ad sp show --id "$APP_ID" &>/dev/null || az ad sp create --id "$APP_ID" >/dev/null
SP_OBJECT_ID=$(az ad sp show --id "$APP_ID" --query id -o tsv)

# Role Contributor limite au RG dedie
MSYS_NO_PATHCONV=1 az role assignment create \
  --assignee-object-id "$SP_OBJECT_ID" --assignee-principal-type ServicePrincipal \
  --role "Contributor" \
  --scope "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}" \
  2>/dev/null && echo "role attribue" || echo "role deja present (ok)"

# Federated credentials (1 par depot, sur main)
for REPO in "${GH_REPOS[@]}"; do
  FC_NAME="gh-${REPO}-main"
  if az ad app federated-credential list --id "$APP_ID" \
       --query "[?name=='${FC_NAME}']" -o tsv | grep -q "$FC_NAME"; then
    echo "$FC_NAME : deja present"
  else
    az ad app federated-credential create --id "$APP_ID" --parameters "{
      \"name\": \"${FC_NAME}\",
      \"issuer\": \"https://token.actions.githubusercontent.com\",
      \"subject\": \"repo:${GH_ORG}/${REPO}:ref:refs/heads/main\",
      \"audiences\": [\"api://AzureADTokenExchange\"]
    }" >/dev/null
    echo "$FC_NAME : cree"
  fi
done

TENANT_ID=$(az account show --query tenantId -o tsv)
echo ""
echo ">>> Secrets GitHub (les 3 depots) :"
echo "    AZURE_CLIENT_ID       = $APP_ID"
echo "    AZURE_TENANT_ID       = $TENANT_ID"
echo "    AZURE_SUBSCRIPTION_ID = $SUBSCRIPTION_ID"
echo "    SP_OBJECT_ID          = $SP_OBJECT_ID"