#!/usr/bin/env bash
# Smoke test rejouable : le front répond, /api/ traverse nginx jusqu'au backend
# et la réponse vient de PostgreSQL (liste des certifications).
# Lecture seule (GET uniquement). L'URL vient de `terraform output -raw ingress_host`,
# préfixée de http://. Usage :
#   SMOKE_API_KEY=<clé> ./scripts/smoke-test.sh <base_url>
set -euo pipefail

BASE_URL="${1:-${SMOKE_BASE_URL:?base URL requise : argument ou SMOKE_BASE_URL (terraform output -raw ingress_host)}}"
API_KEY="${SMOKE_API_KEY:?SMOKE_API_KEY requis (clé attendue par le backend, en-tête X-Api-Key)}"
fail=0

code() { curl -s -o /dev/null -w '%{http_code}' --max-time 15 "$@"; }
report() { if [ "$2" = ok ]; then echo "OK   $1"; else echo "FAIL $1"; fail=1; fi; }

[ "$(code "$BASE_URL/")" = 200 ] && r=ok || r=ko
report "front : GET / renvoie 200" "$r"

[ "$(code "$BASE_URL/healthz")" = 200 ] && r=ok || r=ko
report "front : healthz renvoie 200" "$r"

c=$(code "$BASE_URL/api/certifications")
{ [ "$c" = 401 ] || [ "$c" = 403 ]; } && r=ok || r=ko
report "api : sans clé, refus 401 ou 403" "$r"

[ "$(code -H "X-Api-Key: $API_KEY" "$BASE_URL/api/certifications")" = 200 ] && r=ok || r=ko
report "api : avec clé, 200 via nginx" "$r"

if curl -s --max-time 15 -H "X-Api-Key: $API_KEY" "$BASE_URL/api/certifications" \
  | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if isinstance(d,list) and d else 1)"; then r=ok; else r=ko; fi
report "api : réponse JSON non vide (données PostgreSQL)" "$r"

exit "$fail"
