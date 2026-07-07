// Health endpoints. Wire into your server, e.g.:
//   app.get('/healthz', () => Response.json(healthz()))
//   app.get('/readyz',  async () => Response.json(await readyz()))
// PRESERVE: this file is yours to edit — re-seeding writes health.ts.seed instead.

export function healthz() {
  return { status: 'ok', ts: new Date().toISOString() }
}

// Extend with real readiness checks (db ping, cache ping, migrations applied…).
export async function readyz() {
  const checks: Record<string, 'ok' | 'fail'> = {}
  // checks.db = (await pingDb()) ? 'ok' : 'fail'
  const ok = Object.values(checks).every((v) => v === 'ok')
  return { status: ok ? 'ok' : 'degraded', checks, ts: new Date().toISOString() }
}
