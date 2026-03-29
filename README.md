# k3s PostgreSQL Grafana Platform

## Project overview

This repository implements the platform layer for an already working single-node k3s cluster.

The solution delivers:

- A parent Helm chart at `charts/platform`
- PostgreSQL deployed by Helm using the Bitnami chart
- kube-prometheus-stack for Prometheus, Alertmanager, and Grafana
- Loki for log storage and querying
- Alloy for Kubernetes log collection
- A minimal FastAPI TODO app using plain SQL only
- A Helm hook Job that initializes the TODO schema and enables `pg_stat_statements`
- Customer-facing `kubectl`-only start and stop scripts
- Verification helpers and presentation-oriented documentation

## Architecture summary

- Traefik ingress routes traffic to the FastAPI service.
- The FastAPI app connects to PostgreSQL with plain SQL through `psycopg`.
- PostgreSQL runs as a single persistent StatefulSet with slow query logging enabled for statements slower than 1 second.
- The Bitnami PostgreSQL exporter sidecar exposes metrics, including a custom `pg_stat_statements` rollup used for query rate and mean latency.
- kube-prometheus-stack scrapes cluster and PostgreSQL metrics and provisions Grafana.
- Alloy tails logs from Kubernetes Pods in the platform namespace and writes them into Loki.
- Loki ruler evaluates a log-based alert when more than 3 slow SQL statements are logged within 10 minutes.

A fuller breakdown is in [docs/architecture.md](docs/architecture.md).

## Assumptions

- Ubuntu 24
- k3s already installed and healthy
- `kubectl`, `make`, and `helm` already installed
- `docker` installed if you will build the FastAPI image from this VM
- Existing k3s defaults are available: ingress controller, local-path storage, node metrics
- You are not bootstrapping Kubernetes from zero in this iteration
- The app image is built outside Helm, then imported into k3s or pushed to a registry

The older bootstrap notes remain in [BOOTSTRAP.md](BOOTSTRAP.md), but they are background context for this iteration rather than the main workflow.

## Repository layout

```text
.
├── README.md
├── Makefile
├── app/
├── charts/platform/
├── docs/
├── scripts/
└── BOOTSTRAP.md
```

Notable implementation detail:

- The dashboard source lives in `charts/platform/templates/grafana-dashboard-db.tpl` instead of `.json` because Helm rejects `.json` files inside `templates/` during lint/render.

## Build and image distribution

### Option A: local VM build plus import into k3s

This matches the default `app.image.repository` and `app.image.tag` values in `values.dev.yaml`.
That dev overlay now uses `imagePullPolicy: Never` on purpose so a missed image import fails fast instead of hanging on a pull from a non-existent registry.

```bash
docker build -t platform/todo-api:dev app
docker save platform/todo-api:dev | sudo k3s ctr images import -
```

### Option B: push to a registry

If you prefer a remote registry:

```bash
docker build -t <registry>/<repo>/todo-api:<tag> app
docker push <registry>/<repo>/todo-api:<tag>
```

Then override the image in a custom values file or with `--set`.
If you switch away from the local imported image flow, also override `app.image.pullPolicy` from `Never` to `IfNotPresent` or `Always`.

## Install steps

The examples below assume `RELEASE=platform` and `NAMESPACE=platform`.
Resource names now derive from the Helm release, so a different release name will produce a different prefix.
The runtime namespace comes from Helm `-n/--namespace`; there is no separate namespace value to keep in sync.

### 1. Confirm the cluster is ready

```bash
kubectl get nodes
kubectl get storageclass
kubectl get pods -n kube-system | egrep 'traefik|metrics'
kubectl top nodes
```

### 2. Build the chart dependencies

```bash
make deps
```

This command:

- reads `Chart.yaml` and `Chart.lock`
- downloads the dependency chart archives into `charts/platform/charts/`
- makes sure the parent chart has the subcharts it needs before lint, template, or deploy

### 3. Review the values files

The chart keeps two intended inputs:

- `charts/platform/values.yaml` - a neutral base file with blank credential defaults.
- `charts/platform/values.dev.yaml` - a convenient local/demo overlay.

Important defaults in `values.dev.yaml`:

- ingress host: `todo.localtest.me`
- app image: `platform/todo-api:dev`
- demo passwords for PostgreSQL and Grafana

### 4. Choose an install path

#### Local/dev install with `values.dev.yaml`

`make deploy` still uses the local/demo overlay:

```bash
make deploy
```

Equivalent raw Helm command:

```bash
helm upgrade --install platform charts/platform \
  -n platform \
  --create-namespace \
  -f charts/platform/values.yaml \
  -f charts/platform/values.dev.yaml
```

#### Explicit value-based install

```bash
helm upgrade --install platform charts/platform \
  -n platform \
  --create-namespace \
  -f charts/platform/values.yaml \
  --set-string ingress.host=todo.example.local \
  --set-string postgresql.auth.password=todoapp-demo-password \
  --set-string postgresql.auth.postgresPassword=postgres-demo-password \
  --set-string monitoring.grafana.adminPassword=admin-demo-password
```

#### Existing-secret based install

Use the upstream PostgreSQL secret keys unless you intentionally override them:

```bash
kubectl -n platform create secret generic platform-db-creds \
  --from-literal=postgres-password=postgres-demo-password \
  --from-literal=password=todoapp-demo-password

helm upgrade --install platform charts/platform \
  -n platform \
  --create-namespace \
  -f charts/platform/values.yaml \
  --set-string ingress.host=todo.example.local \
  --set-string postgresql.auth.existingSecret=platform-db-creds \
  --set-string monitoring.grafana.adminPassword=admin-demo-password
```

### Credential behavior

- App DB credential path: set either the shared PostgreSQL credential (`postgresql.auth.password` or `postgresql.auth.existingSecret`) or an explicit app-side source (`app.secrets.databasePassword` or `app.secrets.existingSecret.name` plus `.key`). The app-side override must still match the PostgreSQL application-user password.
- Not parent-guarded: `postgresql.auth.postgresPassword` and `monitoring.grafana.adminPassword` are passed through to their subcharts. If they are unset, upstream chart behavior applies.
- Upstream references: [Bitnami PostgreSQL values](https://github.com/bitnami/charts/blob/main/bitnami/postgresql/values.yaml), [kube-prometheus-stack values](https://github.com/prometheus-community/helm-charts/blob/main/charts/kube-prometheus-stack/values.yaml), [Grafana chart values](https://github.com/grafana/helm-charts/blob/main/charts/grafana/values.yaml)

## Log label contract for PostgreSQL slow-query alerting

Alloy derives Loki stream labels from Kubernetes pod metadata. In this chart, the slow-query alert assumes PostgreSQL logs land under `{namespace="<release namespace>", app="postgresql", container="postgresql"}`.

That works because Alloy relabels the pod namespace, `app.kubernetes.io/name`, and container name, and the Bitnami PostgreSQL StatefulSet keeps `app.kubernetes.io/name=postgresql` with a primary container named `postgresql`. If you change release-driven naming, pod labels, or the relabeling rules enough that those labels no longer match, update the alert query too.

## Preflight checks before demo

- Build and import the FastAPI image expected by `values.dev.yaml`:

```bash
docker build -t platform/todo-api:dev app
docker save platform/todo-api:dev | sudo k3s ctr images import -
sudo k3s ctr images ls | grep 'platform/todo-api.*dev'
```

- Deploy into the `platform` namespace. The Helm release namespace is the runtime source of truth:

```bash
kubectl get ns platform
```

- Expect ingress access through Traefik on `todo.localtest.me` from inside the VM:

```bash
NODE_IP=$(hostname -I | awk '{print $1}')
curl -H 'Host: todo.localtest.me' "http://$NODE_IP/healthz"
```

- Verify Grafana is reachable before the demo:

```bash
./scripts/port-forward-grafana.sh
curl -I http://127.0.0.1:3000/login
```

- Verify Prometheus sees the PostgreSQL and Alloy scrape targets:

```bash
kubectl -n platform port-forward svc/platform-monitoring-prometheus 9090:9090
curl -s 'http://127.0.0.1:9090/api/v1/targets?state=active' | grep -E 'postgresql|alloy'
```

- Verify Loki is receiving PostgreSQL logs:

```bash
kubectl -n platform port-forward svc/platform-loki 3100:3100
curl -G -s 'http://127.0.0.1:3100/loki/api/v1/query' \
  --data-urlencode 'query={namespace="platform",app="postgresql",container="postgresql"}'
```

- Force a slow query for dashboard and alert-path testing:

```bash
POSTGRES_PASSWORD=$(kubectl -n platform get secret platform-postgresql -o jsonpath='{.data.postgres-password}' | base64 -d)
kubectl -n platform exec statefulset/platform-postgresql -- \
  env PGPASSWORD="$POSTGRES_PASSWORD" \
  psql -h 127.0.0.1 -U postgres -d todoapp -c 'SELECT pg_sleep(1.2);'
```

## Validation and smoke tests

### Quick smoke test

```bash
./scripts/verify.sh
```

> If you install with a different release or namespace, run `RELEASE=<release> NAMESPACE=<namespace> ./scripts/verify.sh`.

This checks:

- PostgreSQL rollout
- app rollout
- Grafana rollout
- Alloy rollout
- dashboard and alert ConfigMaps
- `ServiceMonitor` objects for Alloy and PostgreSQL
- API health and basic TODO create/complete flow

### Check the ingress path

From inside the VM:

```bash
NODE_IP=$(hostname -I | awk '{print $1}')
curl -H 'Host: todo.localtest.me' "http://$NODE_IP/healthz"
```

### Open Grafana

```bash
./scripts/port-forward-grafana.sh
```

> If you install with a different release or namespace, run `RELEASE=<release> NAMESPACE=<namespace> ./scripts/port-forward-grafana.sh`.

## Testing slow query logging and alerting

### Generate 4 slow SQL statements

```bash
POSTGRES_PASSWORD=$(kubectl -n platform get secret platform-postgresql -o jsonpath='{.data.postgres-password}' | base64 -d)
for i in 1 2 3 4; do
  kubectl -n platform exec statefulset/platform-postgresql -- \
    env PGPASSWORD="$POSTGRES_PASSWORD" \
    psql -h 127.0.0.1 -U postgres -d todoapp -c 'SELECT pg_sleep(1.2);'
done
```

### Inspect the alert state through Loki

```bash
kubectl -n platform port-forward svc/platform-loki 3100:3100
curl -s http://127.0.0.1:3100/prometheus/api/v1/alerts | jq .
```

If `jq` is unavailable, inspect the raw JSON directly.

## Demo walkthrough

A concise presentation flow:

1. Show `helm dependency build` and the parent chart values structure.
2. Show the PostgreSQL configuration for persistence, `pg_stat_statements`, and slow query logging.
3. Show the FastAPI app and the schema hook Job.
4. Run `./scripts/verify.sh`.
5. Port-forward Grafana and open the PostgreSQL dashboard.
6. Trigger slow queries and show the alert in Loki.
7. Run `./scripts/platform-stop.sh` and explain that observability stays up.
8. Run `./scripts/platform-start.sh` and show recovery.

More detail is in [docs/presentation-notes.md](docs/presentation-notes.md).

## Known limitations

- This is intentionally optimized for a single-node k3s demo, not HA.
- Secrets are value-driven and suitable for a challenge or dev environment, but not hardened secret management.
- The stop/start wrappers restore the last replica counts they recorded themselves; if resources were scaled manually without the wrapper, the start script falls back to `APP_REPLICAS` and `POSTGRES_REPLICAS`.
- Alloy is intentionally kept simple and scoped to the platform namespace.
- No backup, restore, WAL archiving, or disaster recovery workflow is included.
- The FastAPI app is intentionally minimal and does not include authentication, migrations tooling, or broader test coverage.

## Future improvements

See [docs/future-enhancements.md](docs/future-enhancements.md) for a prioritized follow-up list.
