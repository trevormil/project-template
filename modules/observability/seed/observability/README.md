# Observability module

Ships a `/metrics` (Prometheus) endpoint + structured logging + a Loki log driver.
Roles across the shared platform: **Loki = logs, Prometheus = metrics, shared PG =
product/feedback/analytics events**. The Admin panel queries Prometheus/Loki over HTTP.

- `src/telemetry.ts` — logger + metrics registry (PRESERVE: yours to extend).
- Local-first: logs also land as `.TerMinal/telemetry/*.jsonl` in dev (offline).

> Phase-0 stub — metrics endpoint + Loki wiring flesh out in Phase 2.
