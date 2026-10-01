#!/usr/bin/env bash
# Cree le backend de state Terraform : storage account + container.
# Oeuf-poule : Terraform ne peut pas creer le backend qui heberge son propre
# state, donc on le fait ici, une fois. Idempotent.
set -euo pipefail

SUBSCRIPTION_ID="5e683e0f-b00c-48d6-9769-5aaf598de8f1"
RG_NAME="msaidiRG"
LOCATION="francecentral"
OWNER="mohamed-saidi"
STATE_CONTAINER="tfstate"

az account set --subscription "$SUBSCRIPTION_ID"

# Le compte est retrouvé par tag (idempotent). Le suffixe aléatoire n'est tiré
# qu'à la création : le nom doit être unique à l'échelle d'Azure.
STATE_SA=$(az storage account list -g "$RG_NAME" \
  --query "[?tags.owner=='$OWNER' && tags.component=='tfstate'].name | [0]" -o tsv)
[ -n "$STATE_SA" ] || STATE_SA="tfstate${OWNER//-/}$RANDOM"

if az storage account show -n "$STATE_SA" -g "$RG_NAME" &>/dev/null; then
  echo "storage account deja present : $STATE_SA"
else
  az storage account create \
    --name "$STATE_SA" --resource-group "$RG_NAME" --location "$LOCATION" \
    --sku Standard_LRS --kind StorageV2 \
    --min-tls-version TLS1_2 --allow-blob-public-access false \
    --default-action Deny --bypass AzureServices \
    --tags owner="$OWNER" component=tfstate managed-by=script >/dev/null
  echo "storage account cree : $STATE_SA"
fi

# Plan de gestion (ARM) : fonctionne malgré le firewall et sans rôle data-plane.
az storage container-rm create \
  --name "$STATE_CONTAINER" --storage-account "$STATE_SA" \
  --resource-group "$RG_NAME" >/dev/null && echo "container '$STATE_CONTAINER' pret"

echo ""
echo ">>> A reporter dans backend.tf :"
echo "    storage_account_name = \"$STATE_SA\""
echo "    container_name       = \"$STATE_CONTAINER\""