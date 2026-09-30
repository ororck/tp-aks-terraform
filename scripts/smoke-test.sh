#!/usr/bin/env bash
# Smoke test rejouable : le front répond, /api/ traverse nginx jusqu'au backend
# et la réponse vient de PostgreSQL (liste des certifications).
# Lecture seule (GET uniquement). Usage :
#   SMOKE_API_KEY=<clé> ./scripts/smoke-test.sh [base_url]
set -euo pipefail

BASE_URL="${1:-${SMOKE_BASE_URL:-http://mohamed-saidi.20.74.93.53.nip.io}}"
API_KEY="${SMOKE_API_KEY:?SMOKE_API_KEY requis (clé attendue par le backend, en-tête X-Api-Key)}"
fail=0

check() { # nom, commande de test
  if eval "$2" >/dev/null 2>&1; then echo "OK   $1"; else echo "FAIL $1"; fail=1; fi
}

code() { curl -s -o /dev/null -w '%{http_code}' --max-time 15 "$@"; }

check "front : GET / renvoie 200" '[ "$(code "$BASE_URL/")" = 200 ]'
check "front : healthz renvoie 200" '[ "$(code "$BASE_URL/healthz")" = 200 ]'
check "api : sans clé, refus 401 ou 403" 'c=$(code "$BASE_URL/api/certifications"); [ "$c" = 401 ] || [ "$c" = 403 ]'
check "api : avec clé, 200 via nginx" '[ "$(code -H "X-Api-Key: $API_KEY" "$BASE_URL/api/certifications")" = 200 ]'
check "api : réponse JSON non vide (données PostgreSQL)" \
  'curl -s --max-time 15 -H "X-Api-Key: $API_KEY" "$BASE_URL/api/certifications" | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if isinstance(d,list) and len(d)>0 else 1)"'

exit "$fail"
