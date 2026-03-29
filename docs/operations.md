# Operations

## Common Helm commands

```bash
make deps
make lint
make template
make deploy
helm list -n platform
helm status platform -n platform
helm get values platform -n platform
```

## Common kubectl commands

```bash
kubectl get pods -n platform
kubectl get ingress -n platform
kubectl get svc -n platform
kubectl get configmap -n platform
kubectl get servicemonitor -n platform
kubectl describe pod -n platform <pod-name>
```

## Where to look for logs

Application logs:

```bash
kubectl logs -n platform deploy/todo-api
```

PostgreSQL logs:

```bash
kubectl logs -n platform statefulset/postgresql -c postgresql
```

Alloy logs:

```bash
kubectl logs -n platform deploy/alloy
```

Loki logs:

```bash
kubectl logs -n platform statefulset/loki
```

## How to check alerting

### Confirm the rule object exists

```bash
kubectl get configmap -n platform loki-slow-query-rules -o yaml
```

### Generate slow queries

```bash
POSTGRES_PASSWORD=$(kubectl -n platform get secret postgresql -o jsonpath='{.data.postgres-password}' | base64 -d)
for i in 1 2 3 4; do
  kubectl -n platform exec statefulset/postgresql -- \
    env PGPASSWORD="$POSTGRES_PASSWORD" \
    psql -h 127.0.0.1 -U postgres -d todoapp -c 'SELECT pg_sleep(1.2);'
done
```

### Inspect active Loki alerts

```bash
kubectl -n platform port-forward svc/loki 3100:3100
curl -s http://127.0.0.1:3100/prometheus/api/v1/alerts
```

### Inspect slow-query log lines directly

```bash
kubectl -n platform port-forward svc/loki 3100:3100
curl -G -s http://127.0.0.1:3100/loki/api/v1/query \
  --data-urlencode 'query={namespace="platform",app="postgresql",container="postgresql"} |= "duration:" |= "statement:"'
```

## How to verify dashboard data

1. Run `./scripts/port-forward-grafana.sh`.
2. Open Grafana on `http://127.0.0.1:3000`.
3. Open the `Platform PostgreSQL Overview` dashboard.
4. Run `./scripts/verify.sh` or hit the TODO endpoints to create query activity.
5. Confirm the four panels populate:
   - queries per second
   - mean query latency
   - DB pod CPU usage
   - DB pod memory usage

### Check Prometheus scrape targets directly

```bash
kubectl -n platform port-forward svc/monitoring-prometheus 9090:9090
curl -s 'http://127.0.0.1:9090/api/v1/targets?state=active' | grep -E 'postgresql|alloy'
```

## Start and stop operations

Stop application workload while keeping observability online:

```bash
./scripts/platform-stop.sh
```

Start the workload again:

```bash
./scripts/platform-start.sh
```

Override namespace or replicas if needed:

```bash
NAMESPACE=platform APP_REPLICAS=1 POSTGRES_REPLICAS=1 ./scripts/platform-start.sh
```

Replica restore behavior:

- `platform-stop.sh` records the current app and PostgreSQL replica counts in resource annotations before scaling them to zero.
- `platform-start.sh` restores from those recorded counts first.
- If no recorded count exists, `platform-start.sh` falls back to `APP_REPLICAS` and `POSTGRES_REPLICAS`.

## Recovery guide

### If PostgreSQL does not start

1. Check StatefulSet rollout:

```bash
kubectl rollout status statefulset/postgresql -n platform
```

2. Check pod events and logs:

```bash
kubectl describe pod -n platform postgresql-0
kubectl logs -n platform statefulset/postgresql -c postgresql
```

3. Verify PVC binding:

```bash
kubectl get pvc -n platform
```

### If the app does not start

1. Inspect rollout status:

```bash
kubectl rollout status deployment/todo-api -n platform
```

2. Check app logs:

```bash
kubectl logs -n platform deploy/todo-api
```

3. Confirm the PostgreSQL secret and Service are present:

```bash
kubectl get secret,svc -n platform | egrep 'postgresql|todo-api'
```

### If Grafana or Prometheus looks empty

1. Check `ServiceMonitor` objects:

```bash
kubectl get servicemonitor -n platform
```

2. Confirm PostgreSQL exporter service exists:

```bash
kubectl get svc -n platform postgresql-metrics
```

3. Verify Grafana dashboard ConfigMap exists:

```bash
kubectl get configmap -n platform platform-postgresql-dashboard
```
