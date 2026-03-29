#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-platform}"
RELEASE="${RELEASE:-platform}"
APP_LOCAL_PORT="${APP_LOCAL_PORT:-18080}"

release_name() {
  local suffix="$1"

  if [[ "$RELEASE" == *"$suffix"* ]]; then
    printf '%s' "$RELEASE"
  else
    printf '%s-%s' "$RELEASE" "$suffix"
  fi
}

APP_SERVICE="${APP_SERVICE:-$(release_name "todo-api")}"
APP_DEPLOYMENT="${APP_DEPLOYMENT:-$APP_SERVICE}"
GRAFANA_DEPLOYMENT="${GRAFANA_DEPLOYMENT:-$(release_name "grafana")}"
POSTGRES_STATEFULSET="${POSTGRES_STATEFULSET:-$(release_name "postgresql")}"
ALLOY_DEPLOYMENT="${ALLOY_DEPLOYMENT:-$(release_name "alloy")}"
POSTGRESQL_DASHBOARD_CONFIGMAP="${POSTGRESQL_DASHBOARD_CONFIGMAP:-$(release_name "postgresql-dashboard")}"
LOKI_RULES_CONFIGMAP="${LOKI_RULES_CONFIGMAP:-$(release_name "loki-slow-query-rules")}"
ALLOY_SERVICE_MONITOR="${ALLOY_SERVICE_MONITOR:-$(release_name "alloy")}"
POSTGRESQL_SERVICE_MONITOR="${POSTGRESQL_SERVICE_MONITOR:-$(release_name "postgresql")}"
APP_INGRESS="${APP_INGRESS:-$APP_SERVICE}"

cleanup() {
  if [[ -n "${PF_PID:-}" ]] && kill -0 "$PF_PID" >/dev/null 2>&1; then
    kill "$PF_PID" >/dev/null 2>&1 || true
    wait "$PF_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

echo "Waiting for core workloads..."
kubectl -n "$NAMESPACE" rollout status "statefulset/$POSTGRES_STATEFULSET" --timeout=180s
kubectl -n "$NAMESPACE" rollout status "deployment/$APP_DEPLOYMENT" --timeout=180s
kubectl -n "$NAMESPACE" rollout status "deployment/$GRAFANA_DEPLOYMENT" --timeout=180s
kubectl -n "$NAMESPACE" rollout status "deployment/$ALLOY_DEPLOYMENT" --timeout=180s

echo "Checking Helm-managed observability assets..."
kubectl -n "$NAMESPACE" get configmap "$POSTGRESQL_DASHBOARD_CONFIGMAP" "$LOKI_RULES_CONFIGMAP" >/dev/null
kubectl -n "$NAMESPACE" get servicemonitor "$ALLOY_SERVICE_MONITOR" "$POSTGRESQL_SERVICE_MONITOR" >/dev/null

echo "Port-forwarding app service for API smoke tests..."
kubectl -n "$NAMESPACE" port-forward "service/$APP_SERVICE" "$APP_LOCAL_PORT:80" >/tmp/platform-verify-port-forward.log 2>&1 &
PF_PID=$!
sleep 5

curl -fsS "http://127.0.0.1:$APP_LOCAL_PORT/healthz" >/dev/null

CREATE_RESPONSE="$(curl -fsS -X POST "http://127.0.0.1:$APP_LOCAL_PORT/todos" \
  -H 'Content-Type: application/json' \
  -d '{"title":"verify script todo"}')"
TODO_ID="$(printf '%s' "$CREATE_RESPONSE" | python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])')"

curl -fsS -X POST "http://127.0.0.1:$APP_LOCAL_PORT/todos/$TODO_ID/complete" >/dev/null
curl -fsS "http://127.0.0.1:$APP_LOCAL_PORT/todos" >/dev/null

echo "Verification complete."
echo "Created and completed todo id: $TODO_ID"
echo "Ingress host: $(kubectl -n "$NAMESPACE" get ingress "$APP_INGRESS" -o jsonpath='{.spec.rules[0].host}')"
