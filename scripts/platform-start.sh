#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-platform}"
APP_DEPLOYMENT="${APP_DEPLOYMENT:-todo-api}"
POSTGRES_STATEFULSET="${POSTGRES_STATEFULSET:-postgresql}"
APP_REPLICAS="${APP_REPLICAS:-1}"
POSTGRES_REPLICAS="${POSTGRES_REPLICAS:-1}"
REPLICA_ANNOTATION="${REPLICA_ANNOTATION:-platform.example.io/original-replicas}"

require_namespace() {
  kubectl get namespace "$NAMESPACE" >/dev/null
}

resolve_replicas() {
  local resource="$1"
  local fallback="$2"
  local recorded

  if ! kubectl -n "$NAMESPACE" get "$resource" >/dev/null 2>&1; then
    echo "ERROR: missing resource $resource in namespace $NAMESPACE" >&2
    exit 1
  fi

  recorded="$(kubectl -n "$NAMESPACE" get "$resource" -o "go-template={{ index .metadata.annotations \"$REPLICA_ANNOTATION\" }}")"
  if [[ -n "$recorded" ]]; then
    printf '%s' "$recorded"
  else
    printf '%s' "$fallback"
  fi
}

clear_recorded_replicas() {
  local resource="$1"
  kubectl -n "$NAMESPACE" annotate "$resource" "${REPLICA_ANNOTATION}-" >/dev/null 2>&1 || true
}

require_namespace

POSTGRES_TARGET_REPLICAS="$(resolve_replicas "statefulset/$POSTGRES_STATEFULSET" "$POSTGRES_REPLICAS")"
APP_TARGET_REPLICAS="$(resolve_replicas "deployment/$APP_DEPLOYMENT" "$APP_REPLICAS")"

echo "Starting PostgreSQL in namespace $NAMESPACE"
echo "Restoring statefulset/$POSTGRES_STATEFULSET to $POSTGRES_TARGET_REPLICAS replica(s)"
kubectl -n "$NAMESPACE" scale "statefulset/$POSTGRES_STATEFULSET" --replicas="$POSTGRES_TARGET_REPLICAS" >/dev/null
kubectl -n "$NAMESPACE" rollout status "statefulset/$POSTGRES_STATEFULSET" --timeout=180s
clear_recorded_replicas "statefulset/$POSTGRES_STATEFULSET"

echo "Starting app deployment in namespace $NAMESPACE"
echo "Restoring deployment/$APP_DEPLOYMENT to $APP_TARGET_REPLICAS replica(s)"
kubectl -n "$NAMESPACE" scale "deployment/$APP_DEPLOYMENT" --replicas="$APP_TARGET_REPLICAS" >/dev/null
kubectl -n "$NAMESPACE" rollout status "deployment/$APP_DEPLOYMENT" --timeout=180s
clear_recorded_replicas "deployment/$APP_DEPLOYMENT"

echo "Platform workload is back up."
kubectl -n "$NAMESPACE" get deploy,statefulset
