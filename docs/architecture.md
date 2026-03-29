# Architecture

## Scope boundaries

Helm owns:

- PostgreSQL deployment and configuration
- Prometheus, Alertmanager, and Grafana
- Loki
- Alloy
- FastAPI application manifests
- Ingress
- Schema initialization Job
- Dashboard and alert rule provisioning

Outside Helm by design:

- Initial Kubernetes installation
- Building or publishing the app image
- Customer-facing start and stop wrapper scripts

## Component diagram

```text
User / curl / browser
        |
        v
  k3s Traefik Ingress
        |
        v
   FastAPI Deployment -----> PostgreSQL StatefulSet
        |                         |
        |                         +--> slow query logs to container stdout/stderr
        |                         +--> exporter sidecar exposes PostgreSQL metrics
        |
        +--> health and TODO endpoints

Alloy Deployment --tails platform namespace pod logs--> Loki SingleBinary
                                                     |
                                                     +--> Loki ruler evaluates slow-query log alert
                                                     +--> alert sent to Alertmanager

Prometheus <---- ServiceMonitor ---- PostgreSQL metrics exporter
Prometheus <---- cluster metrics ---- kubelet / node / kube-state-metrics
Grafana    <---- Prometheus datasource + Loki datasource from kube-prometheus-stack/Loki integration
```

## Request flow

1. Traefik receives an HTTP request for the configured host.
2. The Ingress sends traffic to the `todo-api` Service.
3. The FastAPI app performs plain SQL queries against PostgreSQL.
4. The schema hook ensures the required `todos` table exists after install and upgrade.

## Metrics flow

1. The Bitnami PostgreSQL chart deploys an exporter sidecar.
2. The exporter exposes built-in PostgreSQL metrics and a custom `pg_stat_statements` rollup.
3. Prometheus scrapes the exporter via `ServiceMonitor`.
4. Grafana uses the Prometheus datasource to render:
   - queries per second
   - mean query latency
   - DB pod CPU usage
   - DB pod memory usage

## Logging flow

1. PostgreSQL writes slow statements over 1 second to container logs.
2. Alloy discovers Pods in the platform namespace using the Kubernetes API.
3. Alloy relabels key Kubernetes metadata into query-friendly Loki labels such as `namespace`, `pod`, `container`, and `app`.
4. Alloy writes log streams into Loki.
5. Loki ruler runs a LogQL alert over PostgreSQL slow-query log lines.

## Alerting flow

1. Loki ruler loads the rule from a Helm-managed ConfigMap.
2. The rule counts slow-query log lines over a 10-minute window.
3. When the threshold exceeds 3, Loki creates an active alert.
4. The alert is sent to the Alertmanager service from kube-prometheus-stack.
5. No notification integration is configured in this challenge scope.

## Operational control flow

- `scripts/platform-stop.sh` scales down only the app Deployment and PostgreSQL StatefulSet.
- `scripts/platform-start.sh` scales those workloads back up.
- Observability stays online by default so logs, metrics, and alerts remain available during troubleshooting and recovery.
