#!/usr/bin/env bash
# health.sh — DETERMINISTIC health check → ticket. No model call.
# Script-first agent: the runner executes this .sh directly (no LLM engine).
set -euo pipefail

URL="${HEALTH_URL:-http://localhost:3000/healthz}"

if curl -fsS --max-time 10 "$URL" 2>/dev/null | grep -q '"status":[[:space:]]*"ok"'; then
  echo "health ok: $URL"
  exit 0
fi

echo "health FAILED: $URL"
# Full-auto factory wiring — file a ticket deterministically (no model).
terminal-cli ticket "Health check failing: ${URL}" \
  "The health endpoint ${URL} did not return status \"ok\" at $(date -u +%FT%TZ). Investigate the service." || true
exit 1
