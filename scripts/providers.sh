#!/usr/bin/env bash
# Enregistre les providers de ressources Azure necessaires au TP.
# Idempotent : un provider deja enregistre est simplement re-confirme.
set -euo pipefail

SUBSCRIPTION_ID="5e683e0f-b00c-48d6-9769-5aaf598de8f1"

az account set --subscription "$SUBSCRIPTION_ID"

for P in Microsoft.ContainerService Microsoft.DBforPostgreSQL \
         Microsoft.Cache Microsoft.KeyVault Microsoft.Storage; do
  STATE=$(az provider show -n "$P" --query registrationState -o tsv)
  echo "$P : $STATE"
  if [ "$STATE" != "Registered" ]; then
    az provider register -n "$P"
    echo "  -> register lance"
  fi
done