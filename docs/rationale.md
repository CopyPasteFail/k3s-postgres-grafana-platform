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
