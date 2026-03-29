# Future enhancements

## Bootstrap-from-zero automation

- Add full machine bootstrap automation for Ubuntu, k3s install, kubeconfig setup, and validation.
- Capture the current manual assumptions from `BOOTSTRAP.md` in code.

## Stronger secret handling

- Replace dev-style value-driven secrets with SOPS, Vault, or External Secrets.
- Separate demo defaults from production overrides more aggressively.

## HA and backup/restore direction

- Evaluate PostgreSQL HA strategy and backup tooling.
- Add WAL archiving, restore drills, and documented recovery objectives.
- Move Loki to object storage-backed mode if retention or durability requirements grow.

## Better lifecycle control for start/stop

- Preserve desired replica counts automatically before stop.
- Add optional deep-stop mode for observability shutdown.
- Add status output that summarizes what remains online after each action.

## Notification integrations

- Wire Alertmanager to email, Slack, PagerDuty, or webhook receivers.
- Add alert routing and severity policies.

## Stronger DB migrations

- Replace the hook-only approach with versioned migrations.
- Add rollback and drift detection strategy.

## App hardening

- Add authentication, request validation depth, structured logging, and app metrics.
- Introduce connection pooling and more resilient error handling.
- Add OpenAPI-friendly examples and better response envelopes if needed.

## Test coverage improvements

- Add Helm template tests and chart policy checks.
- Add API unit tests and integration tests against PostgreSQL.
- Add smoke-test automation in CI for image build, deploy, verify, and teardown.
