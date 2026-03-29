#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-platform}"
APP_DEPLOYMENT="${APP_DEPLOYMENT:-todo-api}"
POSTGRES_STATEFULSET="${POSTGRES_STATEFULSET:-postgresql}"
REPLICA_ANNOTATION="${REPLICA_ANNOTATION:-platform.example.io/original-replicas}"

require_namespace() {
  kubectl get namespace "$NAMESPACE" >/dev/null
}

record_and_scale_down() {
  local resource="$1"
  local current_replicas

  if ! kubectl -n "$NAMESPACE" get "$resource" >/dev/null 2>&1; then
    echo "ERROR: missing resource $resource in namespace $NAMESPACE" >&2
    exit 1
  fi

  current_replicas="$(kubectl -n "$NAMESPACE" get "$resource" -o jsonpath='{.spec.replicas}')"
  current_replicas="${current_replicas:-0}"

  if [[ "$current_replicas" != "0" ]]; then
    kubectl -n "$NAMESPACE" annotate "$resource" "$REPLICA_ANNOTATION=$current_replicas" --overwrite >/dev/null
    echo "Recorded $resource replica count: $current_replicas"
  else
    echo "$resource is already scaled to 0; keeping any previously recorded restore value."
  fi

  echo "Scaling $resource to 0"
  kubectl -n "$NAMESPACE" scale "$resource" --replicas=0 >/dev/null
}

require_namespace

echo "Stopping application workload in namespace $NAMESPACE"
record_and_scale_down "deployment/$APP_DEPLOYMENT"
record_and_scale_down "statefulset/$POSTGRES_STATEFULSET"

echo "Observability components remain running by default."
kubectl -n "$NAMESPACE" get deploy,statefulset
