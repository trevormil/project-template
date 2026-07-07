// Feedback capture. Wire into your server, e.g.:
//   app.post('/feedback', async (req) => { await captureFeedback(await req.json()); return new Response(null,{status:204}) })
// PRESERVE: this file is yours to edit — re-seeding writes feedback.ts.seed instead.
import { appendFileSync, mkdirSync } from 'node:fs'
import { execFileSync } from 'node:child_process'

const STORE = '.TerMinal/telemetry/feedback.jsonl' // dev; prod ships to shared PG

export type Feedback = { message: string; url?: string; email?: string; meta?: unknown }

export async function captureFeedback(f: Feedback) {
  const row = { ...f, ts: new Date().toISOString() }
  mkdirSync('.TerMinal/telemetry', { recursive: true })
  appendFileSync(STORE, JSON.stringify(row) + '\n')
  // Full-auto factory wiring: file a ticket immediately (best-effort).
  try {
    execFileSync('terminal-cli', ['ticket', `Feedback: ${f.message.slice(0, 60)}`, f.message], {
      stdio: 'ignore',
    })
  } catch {
    // terminal-cli not on PATH (e.g. prod) — the triage cron will pick it up from the store.
  }
}
