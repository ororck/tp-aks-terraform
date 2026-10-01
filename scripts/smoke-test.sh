#!/usr/bin/env bash
# Smoke test rejouable : le front répond, /api/ traverse nginx jusqu'au backend
# (réponse issue de PostgreSQL) et le backend n'est joignable que par ce chemin
# (isolation réseau, ADR 0009). Lecture seule (GET et kubectl get uniquement).
# L'URL vient de `terraform output -raw ingress_host`, préfixée de http://. Usage :
#   SMOKE_NAMESPACE=<namespace> ./scripts/smoke-test.sh <base_url>
set -euo pipefail

BASE_URL="${1:-${SMOKE_BASE_URL:?base URL requise : argument ou SMOKE_BASE_URL (terraform output -raw ingress_host)}}"
NS="${SMOKE_NAMESPACE:?SMOKE_NAMESPACE requis (namespace de l'application, pour les contrôles d'isolation)}"
fail=0

code() { curl -s -o /dev/null -w '%{http_code}' --max-time 15 "$@" || true; }
report() { if [ "$2" = ok ]; then echo "OK   $1"; else echo "FAIL $1"; fail=1; fi; }

[ "$(code "$BASE_URL/")" = 200 ] && r=ok || r=ko
report "front : GET / renvoie 200" "$r"

[ "$(code "$BASE_URL/healthz")" = 200 ] && r=ok || r=ko
report "front : healthz renvoie 200" "$r"

[ "$(code "$BASE_URL/api/certifications")" = 200 ] && r=ok || r=ko
report "api : GET /api/certifications renvoie 200 via nginx" "$r"

if curl -s --max-time 15 "$BASE_URL/api/certifications" \
  | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if isinstance(d,list) and d else 1)"; then r=ok; else r=ko; fi
report "api : réponse JSON non vide (données PostgreSQL)" "$r"

# Isolation réseau : le backend n'a qu'un chemin d'entrée, le proxy du front.
[ "$(kubectl -n "$NS" get svc backend -o jsonpath='{.spec.type}')" = ClusterIP ] && r=ok || r=ko
report "isolation : le Service backend est de type ClusterIP" "$r"

[ -z "$(kubectl -n "$NS" get svc backend -o jsonpath='{.spec.externalIPs[*]}{.status.loadBalancer.ingress[*].ip}')" ] && r=ok || r=ko
report "isolation : le Service backend n'a aucune IP externe" "$r"

kubectl -n "$NS" get networkpolicy default-deny-ingress allow-frontend-to-backend >/dev/null 2>&1 && r=ok || r=ko
report "isolation : NetworkPolicies default-deny-ingress et allow-frontend-to-backend présentes" "$r"

CIP=$(kubectl -n "$NS" get svc backend -o jsonpath='{.spec.clusterIP}')
[ "$(code --max-time 5 "http://$CIP:8080/actuator/health")" = 000 ] && r=ok || r=ko
report "isolation : le backend n'est pas joignable directement depuis l'extérieur du cluster" "$r"

# /api/ est la seule route vers le backend : ses autres chemins ne sont pas exposés.
if curl -s --max-time 15 "$BASE_URL/actuator/health" | python3 -c "import sys; sys.exit(1 if '\"status\"' in sys.stdin.read() else 0)"; then r=ok; else r=ko; fi
report "isolation : /actuator/health du backend n'est pas exposé par l'Ingress" "$r"

exit "$fail"
