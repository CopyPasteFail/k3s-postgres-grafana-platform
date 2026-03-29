#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-platform}"
GRAFANA_SERVICE="${GRAFANA_SERVICE:-monitoring-grafana}"
GRAFANA_SECRET="${GRAFANA_SECRET:-monitoring-grafana}"
LOCAL_PORT="${LOCAL_PORT:-3000}"

if kubectl -n "$NAMESPACE" get secret "$GRAFANA_SECRET" >/dev/null 2>&1; then
  USERNAME="$(kubectl -n "$NAMESPACE" get secret "$GRAFANA_SECRET" -o jsonpath='{.data.admin-user}' | base64 -d)"
  PASSWORD="$(kubectl -n "$NAMESPACE" get secret "$GRAFANA_SECRET" -o jsonpath='{.data.admin-password}' | base64 -d)"
  echo "Grafana credentials: $USERNAME / $PASSWORD"
fi

echo "Forwarding Grafana to http://127.0.0.1:$LOCAL_PORT"
exec kubectl -n "$NAMESPACE" port-forward "service/$GRAFANA_SERVICE" "$LOCAL_PORT:80"
