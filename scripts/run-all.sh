#!/usr/bin/env bash
# Enchaine les scripts de bootstrap dans l'ordre. S'arrete au premier echec.
set -euo pipefail
cd "$(dirname "$0")"

echo "=== 01 providers ==="      && bash providers.sh
echo "=== 02 state backend ===" && bash storage-container.sh
echo "=== 03 oidc ==="          && bash oidc.sh
echo ""
echo "=== bootstrap termine ==="