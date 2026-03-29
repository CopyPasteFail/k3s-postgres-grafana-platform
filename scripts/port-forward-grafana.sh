#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-platform}"
RELEASE="${RELEASE:-platform}"
LOCAL_PORT="${LOCAL_PORT:-3000}"

release_name() {
  local suffix="$1"

  if [[ "$RELEASE" == *"$suffix"* ]]; then
    printf '%s' "$RELEASE"
  else
    printf '%s-%s' "$RELEASE" "$suffix"
  fi
}

GRAFANA_SERVICE="${GRAFANA_SERVICE:-$(release_name "grafana")}"
GRAFANA_SECRET="${GRAFANA_SECRET:-$GRAFANA_SERVICE}"

if kubectl -n "$NAMESPACE" get secret "$GRAFANA_SECRET" >/dev/null 2>&1; then
  USERNAME="$(kubectl -n "$NAMESPACE" get secret "$GRAFANA_SECRET" -o jsonpath='{.data.admin-user}' | base64 -d)"
  PASSWORD="$(kubectl -n "$NAMESPACE" get secret "$GRAFANA_SECRET" -o jsonpath='{.data.admin-password}' | base64 -d)"
  echo "Grafana credentials: $USERNAME / $PASSWORD"
fi

echo "Forwarding Grafana to http://127.0.0.1:$LOCAL_PORT"
exec kubectl -n "$NAMESPACE" port-forward "service/$GRAFANA_SERVICE" "$LOCAL_PORT:80"
