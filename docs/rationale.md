# Rationale

## Reuse existing k3s rather than bootstrap from zero

Decision
- Reuse the already working k3s installation and treat cluster bootstrap as a prerequisite for this iteration.

Rationale
- The challenge outcome is the platform layer, not Kubernetes installation.
- k3s already provides ingress, local storage, and node metrics, which keeps the implementation focused.
- Reusing the cluster avoids spending the time budget on cluster mechanics instead of platform design.

Tradeoffs
- The repo does not yet fully automate infrastructure bootstrap.
- Reproducibility depends on the VM already matching the documented assumptions.

Alternatives considered
- Full bootstrap automation from scratch in this iteration.
- A different Kubernetes distribution.

Production-hardening follow-up
- Add end-to-end VM or cloud bootstrap automation with idempotent install and validation.

## Use a single parent Helm chart

Decision
- Implement one parent chart at `charts/platform` that owns the application platform layer.

Rationale
- A parent chart makes dependencies explicit and keeps the deployment story easy to present.
- It provides one release boundary for install, upgrade, rollback, and configuration.
- It keeps the native app resources, dashboard, alert rule, and schema hook close to the dependency wiring they rely on.

Tradeoffs
- The parent chart becomes the main integration point, so values need discipline to stay readable.
- Subchart defaults can still be large and noisy if not curated.

Alternatives considered
- Separate independent Helm releases for each component.
- Kustomize layered over multiple third-party releases.

Production-hardening follow-up
- Split environment overlays and possibly publish the parent chart with CI validation.

## Prefer production-ready subcharts over custom templates

Decision
- Use existing charts for PostgreSQL, kube-prometheus-stack, Loki, and Alloy instead of hand-rolled manifests.

Rationale
- Those charts already solve persistence, probes, services, RBAC, CRDs, and upgrade conventions.
- This approach spends time on integration and explanation rather than recreating mature packaging.
- It aligns with the challenge constraint to prefer production-grade subcharts where appropriate.

Tradeoffs
- Subcharts bring extra defaults and a larger rendered manifest set.
- Some behaviors require reading upstream chart conventions carefully.

Alternatives considered
- Writing custom StatefulSets, Deployments, and RBAC from scratch.
- Replacing charts with raw manifests plus manual templating.

Production-hardening follow-up
- Add automated rendered-manifest validation and chart upgrade checks.

## Explain the chosen `values.yaml` shape by component

Decision
- Keep `charts/platform/values.yaml` opinionated at the component level, with a neutral base file that encodes the intended platform behavior without turning every upstream knob into local policy.

Rationale
- For ingress, the values intentionally describe one simple public entrypoint: `enabled: true`, `className: traefik`, `path: /`, and a placeholder `host`. That keeps the chart aligned with k3s defaults and makes it obvious that hostname selection is the main environment-specific input while the parent chart owns the route shape.
- For the FastAPI app, the chosen values favor a small single-replica service with explicit image coordinates, a `ClusterIP` service on port `80`, modest `100m/128Mi` requests, and only a small override surface for scheduling, security context, and extra environment. The goal is to prove the platform works end to end while keeping the application contract readable and avoiding a chart that mostly mirrors raw pod spec syntax.
- For PostgreSQL, the values deliberately express a single-node durable demo database: `architecture: standalone`, `local-path` persistence, an `8Gi` volume, bounded resources, shared application credentials, and `extendedConfiguration` that enables `pg_stat_statements` plus `log_min_duration_statement = 1000`. Those choices support the dashboard and slow-query alert path directly, so the values describe the operational story rather than only the database runtime.
- For monitoring, the values keep kube-prometheus-stack focused on what the platform actually uses: Grafana stays enabled but built-in dashboards are disabled, Prometheus selectors are opened so the stack will see the chart's `ServiceMonitor` resources, and `monitoring.slowQueryAlert` holds the chart-owned alert threshold of `3` events in `10m`. The goal is to keep monitoring values centered on this platform's metric and alerting contract instead of exposing the entire upstream chart surface locally.
- For Loki, the values intentionally choose `SingleBinary`, `filesystem` storage, one persisted replica, and disabled extras like the gateway, canary, and caches. That combination matches the challenge scope: enough durability and retention to demonstrate logs and alerting, but no distributed storage or horizontally scaled log path to explain.
- For Alloy, the values keep one deployment replica, light resources, and an explicit relabeling pipeline in `configMap.content` that turns Kubernetes metadata into the exact Loki labels the alert and log queries use. The important design point is that the values file documents the log contract in one place instead of hiding it behind opaque defaults.

Tradeoffs
- The base values remain intentionally curated rather than exhaustive, so some advanced upstream tuning still requires reading dependency documentation.
- A few choices, such as `postgresql.image.tag: latest` and small default resource sizes, are practical for this demo but would need stronger pinning and capacity review in a production environment.

Alternatives considered
- A very thin values file that mostly delegates decisions to upstream defaults.
- A much larger values file that re-exposes broad subchart configuration for every component.

Production-hardening follow-up
- Add environment-specific overlays for stricter image pinning, storage classes, retention, resource sizing, and secret sourcing while keeping the base file readable.

## Choose Bitnami PostgreSQL

Decision
- Deploy PostgreSQL through the Bitnami chart.

Rationale
- The chart is widely used, supports persistence, a built-in exporter, and clean value-based configuration.
- It made slow query logging and exporter integration straightforward without introducing another operator.
- The chart still works well for a single-instance, no-HA challenge scope.

Tradeoffs
- Bitnami now distributes the live chart through an OCI registry, which is a small packaging nuance to explain.
- The chart exposes many values, so readability depends on curating only the needed ones.

Alternatives considered
- Crunchy or Zalando operators.
- A custom PostgreSQL StatefulSet.

Production-hardening follow-up
- Add backup/restore strategy, version upgrade runbooks, and stronger secret sourcing.

## Choose kube-prometheus-stack

Decision
- Use kube-prometheus-stack for Prometheus, Alertmanager, and Grafana.

Rationale
- It provides the full monitoring stack in one mature chart.
- It already includes Grafana provisioning sidecars and the Prometheus Operator CRDs needed for `ServiceMonitor`.
- It simplifies charting both Kubernetes metrics and PostgreSQL exporter metrics in one place.

Tradeoffs
- It is a large chart and can feel heavy for a demo-sized workload.
- Default rules and components add a lot of rendered resources.

Alternatives considered
- Standalone Prometheus and Grafana charts.
- A lighter metrics stack without Alertmanager.

Production-hardening follow-up
- Trim rules, storage, and retention based on real SLOs and capacity goals.

## Choose Loki for logs

Decision
- Use Loki as the logging backend.

Rationale
- Loki is a natural fit with Grafana and supports LogQL-based alerting directly from log streams.
- The challenge explicitly needs a log-based alert on slow SQL statements.
- The single-binary mode is easy to explain and sufficient for a single-node environment.

Tradeoffs
- Single-binary Loki is not an HA topology.
- Loki chart defaults include optional extras, which needed to be deliberately disabled to keep the footprint focused.

Alternatives considered
- Elasticsearch or OpenSearch.
- Only retaining logs in `kubectl logs` without aggregation.

Production-hardening follow-up
- Move to object storage-backed Loki for higher durability and scale.

## Choose Alloy instead of Promtail

Decision
- Use Alloy for Kubernetes log collection.

Rationale
- The challenge explicitly requested Alloy.
- Alloy can tail Kubernetes logs via the Kubernetes API, so the deployment stays simple and does not need host log mounts for this demo.
- It keeps the logging pipeline modern and aligned with Grafana’s direction.

Tradeoffs
- The Kubernetes API tailing approach is simple here, but it is not the most efficient approach for larger clusters.
- Alloy configuration is powerful, but less familiar to some operators than older Promtail examples.

Alternatives considered
- Promtail.
- Fluent Bit.

Production-hardening follow-up
- Revisit controller shape and discovery strategy for multi-node clusters, likely with clustering or a node-local pattern.

## Explain the chosen Kubernetes objects in overview form

Decision
- Use standard Kubernetes objects that match each component's operational role, and only add parent-owned objects where they carry platform-specific behavior such as schema setup, dashboards, or alert rules.

Rationale
- The FastAPI application is modeled with a `Deployment`, `Service`, and `Ingress` because it is stateless, fronted by HTTP, and expected to roll forward safely. The `Deployment` owns health probes, app config, and the small scheduling/security override surface; the `Service` gives the app a stable in-cluster address on port `80`; and the `Ingress` makes hostname-based access through Traefik explicit. Together, those objects encode the intended request path more clearly than a looser collection of ad hoc resources.
- PostgreSQL and single-binary Loki are kept as `StatefulSet`-backed components with persistent volumes because their value lies in retained data, stable identity, and ordered startup. Using stateful objects for those components keeps the platform honest about persistence, even though the challenge scope is only single-node.
- `ConfigMap` resources are used for the parts of the platform that are configuration or content rather than secrets: app environment, PostgreSQL extended settings, Alloy relabeling config, the Grafana dashboard JSON, and the Loki ruler file. That keeps the operational narrative easy to inspect with `kubectl` and matches the fact that these artifacts are intended to be reviewed and explained during a demo.
- `Secret` resources are used where credentials actually cross boundaries: Grafana admin credentials, PostgreSQL passwords, and the app's DB password source. The parent chart keeps that contract narrow so that secrets are present where needed without making every configuration input sensitive by default.
- The schema initializer is a `Job` wired as a Helm hook because schema setup is part of release lifecycle rather than an always-running workload. That object type matches idempotent one-shot work much better than burying SQL inside application startup or trying to stretch an init container across chart boundaries.
- `ServiceMonitor` resources are used because the monitoring stack is operator-driven and the platform wants scrape intent to be declared next to the workloads being scraped. That is simpler and more reviewable than hand-editing Prometheus scrape configs.
- The slow-query rule and dashboard are delivered as chart-managed config resources rather than runtime-created assets. That keeps the alerting and visualization contract versioned with the chart and makes release-to-release changes inspectable.

Tradeoffs
- Standard objects are easy to reason about, but they still produce a sizable rendered manifest set once mature subcharts are involved.
- Some platform behavior, especially around Grafana and Loki sidecars, depends on upstream object conventions that are not obvious until you inspect the rendered output.

Alternatives considered
- Pushing more behavior into custom application startup logic.
- Replacing chart-managed config resources with manual post-install setup inside the cluster.
- Using operators for more of the stack, especially around database lifecycle.

Production-hardening follow-up
- Add stronger policy around rollout strategy, PodDisruptionBudgets, retention, and secret management while keeping the current object model as the base architecture.

## Keep observability online during default stop flow

Decision
- Default stop behavior scales down the app and PostgreSQL while leaving monitoring and logging up.

Rationale
- Visibility during shutdown and recovery is operationally safer.
- It lets an operator still inspect dashboards, logs, and alert state while bringing workloads back.
- It matches the design decision already made before implementation.

Tradeoffs
- A full stop is not the default path.
- The wrapper scripts need to explain why some components remain running.

Alternatives considered
- A single stop command that scaled everything to zero.
- Using Helm uninstall or Helm value toggles for lifecycle control.

Production-hardening follow-up
- Add optional modes such as `--deep` or saved desired replica counts while keeping the safe default.

## Use kubectl-only wrapper scripts and hide Helm internals

Decision
- Implement start and stop scripts with `kubectl scale` and `kubectl rollout status` only.

Rationale
- This creates a simple customer-facing control surface that does not require Helm knowledge.
- Fixed workload names keep the scripts readable and stable for the demo.
- It respects the explicit challenge constraint.

Tradeoffs
- The wrappers only restore replica counts they recorded themselves.
- They still assume the platform uses the documented namespace and stable resource names.

Alternatives considered
- Helm-based pause and resume commands.
- Custom operators or CRDs for lifecycle management.

Production-hardening follow-up
- Replace the simple annotation-based restore memory with a more durable lifecycle state store if the platform grows beyond a single demo environment.

## Use a Helm hook Job for schema initialization

Decision
- Implement schema initialization as an idempotent `post-install,post-upgrade` hook Job.

Rationale
- It keeps schema setup in the Helm release lifecycle, which matches the challenge constraints.
- `psql` and plain SQL are enough for a tiny TODO schema and are easy to explain.
- The same hook enables `pg_stat_statements` and the table definition in one place.
- The hook explicitly waits for both `pg_isready` and a successful `SELECT 1`, which reduces cold-start races on a fresh install without adding migration tooling.

Tradeoffs
- Hook Jobs are simpler than a real migration workflow, but they are not a substitute for full migration tooling.
- Repeated upgrades need deliberate SQL idempotency.

Alternatives considered
- Init scripts only on first database boot.
- Application-startup migrations.
- Alembic or another migration framework.

Production-hardening follow-up
- Replace the hook with versioned migrations once schema complexity grows.

## Keep the FastAPI app intentionally minimal

Decision
- Build a small FastAPI app with plain SQL, basic health checks, and a few TODO endpoints.

Rationale
- The app exists to prove the platform works end to end, not to be a product by itself.
- Plain SQL directly satisfies the “no ORM” requirement.
- Minimal code reduces noise in the presentation and keeps the database interactions obvious.

Tradeoffs
- No authentication, pagination, or richer error handling.
- No background jobs, migrations framework, or advanced app metrics.

Alternatives considered
- A larger example app.
- SQLAlchemy or another ORM.

Production-hardening follow-up
- Add structured app logging, metrics, tests, auth, and migration tooling.

## Priorities under the 2-hour constraint

Decision
- Prioritize correctness of the platform wiring, observability story, and explainability.

Rationale
- The most important parts of the challenge are the integration choices and the operational narrative.
- That meant preferring a clear, demo-ready stack over optional polish such as HA or advanced secret management.

Tradeoffs
- Some production-hardening tasks were intentionally deferred.
- The default values are dev-oriented rather than enterprise-secure.

Alternatives considered
- Spending more time on one subsystem, such as secrets or app features, at the cost of the full end-to-end platform.

Production-hardening follow-up
- Add CI, backup policy, hardened secrets, HA options, and broader automated tests.

## What was intentionally deferred

Decision
- Defer zero-to-cluster bootstrap automation, HA, backup/restore, notification integrations, and stronger lifecycle state management.

Rationale
- Those items matter, but they are not the best use of a short timebox when the core platform still needs to be demonstrated.
- The current implementation is intentionally the cleanest explainable slice.

Tradeoffs
- The result is solid for a demo, but not production-ready in every operational dimension.

Alternatives considered
- Implementing partial versions of many deferred items and risking a more fragmented result.

Production-hardening follow-up
- Tackle the deferred work in the order listed in [future-enhancements.md](future-enhancements.md).
