# Presentation notes

## Suggested walkthrough

1. Start with the framing.
   - This iteration assumes a working k3s cluster.
   - The repo focuses on the platform layer, observability, and operability.

2. Show the parent chart.
   - One release installs PostgreSQL, monitoring, logging, Alloy, the app, the schema hook, the dashboard, and the alert rule.
   - Values are grouped by `global`, `namespace`, `ingress`, `app`, `postgresql`, `monitoring`, `loki`, and `alloy`.

3. Show the database decisions.
   - Bitnami PostgreSQL for persistence and exporter integration.
   - `pg_stat_statements` enabled.
   - `log_min_duration_statement = 1000` for slow query logging.

4. Show the observability decisions.
   - kube-prometheus-stack for metrics and Grafana.
   - Loki for logs and log-based alerting.
   - Alloy instead of Promtail, using Kubernetes API log tailing for a clean single-node demo.

5. Show the app.
   - Minimal FastAPI, plain SQL only.
   - Health endpoint plus simple TODO endpoints.
   - Hook Job creates the schema on install and upgrade.

6. Run the demo commands.
   - `./scripts/verify.sh`
   - `./scripts/port-forward-grafana.sh`
   - Generate slow queries
   - Show the alert state
   - `./scripts/platform-stop.sh`
   - `./scripts/platform-start.sh`

## Live smoke-test walkthrough

1. Deploy the platform.
   - `make deps`
   - `make deploy`

2. Verify the platform pods are healthy.
   - `kubectl get pods -n platform`
   - `./scripts/verify.sh`

3. Hit the app through ingress.
   - `NODE_IP=$(hostname -I | awk '{print $1}')`
   - `curl -H 'Host: todo.localtest.me' "http://$NODE_IP/healthz"`

4. Create and list a TODO.
   - `curl -H 'Host: todo.localtest.me' -H 'Content-Type: application/json' "http://$NODE_IP/todos" -d '{"title":"demo todo"}'`
   - `curl -H 'Host: todo.localtest.me' "http://$NODE_IP/todos"`

5. Show the Grafana dashboard.
   - `./scripts/port-forward-grafana.sh`
   - Open `Platform PostgreSQL Overview`

6. Show PostgreSQL logs in Loki.
   - `kubectl -n platform port-forward svc/loki 3100:3100`
   - Query `{namespace="platform",app="postgresql",container="postgresql"}`

7. Trigger or explain the alert path.
   - Run `SELECT pg_sleep(1.2);` four times against PostgreSQL.
   - Show `http://127.0.0.1:3100/prometheus/api/v1/alerts`
   - If the alert is still evaluating, explain that Loki is counting slow-query log lines over a 10-minute window.

8. Run the stop/start wrapper flow.
   - `./scripts/platform-stop.sh`
   - `./scripts/platform-start.sh`
   - Explain that observability stays online while app and database replicas are restored from the counts recorded during stop.

## Key design choices to emphasize

- Existing k3s reuse was deliberate to stay focused on the platform layer.
- Mature subcharts were used wherever they reduced risk.
- The stop flow preserves observability by default.
- The alert is genuinely log-based, not inferred from metrics.
- PostgreSQL metrics use `pg_stat_statements` rollups rather than log approximations for query rate and latency.

## Likely questions and prepared answers

### Why not bootstrap Kubernetes from scratch?

- Because the challenge scope here was the platform layer and the VM already had working k3s.
- I documented that tradeoff and left zero-to-cluster bootstrap for a follow-up milestone.

### Why Alloy instead of Promtail?

- The challenge explicitly requested Alloy.
- Alloy also keeps the stack aligned with Grafana’s current agent direction.

### Why single-binary Loki?

- This is a single-node environment.
- Single-binary Loki is enough for the demo and is far easier to explain than an object-storage-backed distributed topology.

### Why not use a migration framework?

- The schema is intentionally tiny.
- A Helm hook Job with plain SQL is the simplest explainable solution that still stays idempotent.

### Why keep monitoring up during stop?

- It is safer operationally.
- During shutdown or recovery you still want logs, dashboards, and alert state available.

### Why not use an ORM?

- The prompt explicitly required plain SQL.
- For this app, plain SQL is also clearer and keeps the data flow easy to demonstrate.

## What to say about tradeoffs and timeboxing

- I prioritized a complete, coherent end-to-end platform over optional polish.
- I deliberately deferred HA, backup/restore, hardened secret management, and notification integrations.
- The result is strong on structure and explainability, while still being honest about what would need to change for production-hardening.
