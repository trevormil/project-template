# Health module

Seeds a `/healthz` + `/readyz` endpoint and a morning health-check cron (disabled
by default). Surfaced red/green in the TerMinal Admin tab.

- `src/health.ts` — the handler (wire it into your server: `app.get('/healthz', healthz)`).
- The `health` agent runs the check on a schedule and files a ticket on failure.

Toggle the cron on from the Admin → Health panel when the endpoint is live.
