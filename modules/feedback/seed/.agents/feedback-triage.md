# feedback-triage

Reads new rows from the local feedback store (`.TerMinal/telemetry/feedback.jsonl`
in dev, shared PG in prod), clusters recurring themes, and files a backlog ticket
per theme via `terminal-cli ticket`. Runs on a disabled-by-default morning cadence;
toggle it on from Admin → Feedback.

Individual feedback submissions also file a ticket immediately at capture time
(see `src/feedback.ts`).
