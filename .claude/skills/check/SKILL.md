---
name: check
description: "Run a repo-level CADENCE inspection (dead-code, dependency drift, etc.) defined by an .agents/<kind>.md spec, and write a dated artifact to .checks/<kind>/<sha>.md. These are deep inspections run weekly/monthly or on demand — NOT per-commit gates. Use when the user runs /check <kind> or asks for a dead-code / hygiene scan."
---

# /check — Cadence repo inspections

Where `/code-review` gates a single PR, `/check` runs a **repo-level inspection**
on the whole tree at `main` HEAD — the deep, slower hygiene scans (dead-code,
dependency drift, license audit, …) that are noise if run per-commit. They run
on a cadence (weekly/monthly) or on demand and produce dated, diff-able
artifacts under `.checks/`.

Each inspection kind is defined by a contract at `.agents/<kind>.md` — see
[`.agents/dead-code.md`](../../../.agents/dead-code.md) for the example + the
pattern to copy when adding a new kind.

## Usage

```
/check dead-code        # run the dead-code inspection
/check                  # list available kinds (the .agents/<kind>.md check specs)
```

Available kinds = the `.agents/*.md` specs that describe cadence checks (i.e.
everything except the per-PR contracts `code-review.md` and `testing.md`).

## Delegate to Codex

Consistent with `/code-review`, delegate the run to Codex from the repo root:

```bash
codex exec -s danger-full-access -C "$PWD" "Run the <kind> inspection following .agents/<kind>.md in this repo exactly. Write the dated artifact to .checks/<kind>/<short-sha>.md with the frontmatter + body the contract specifies. Report only — never delete code or edit source."
```

Run directly in Claude only if `codex` is unavailable or the user asks.

## Process

1. **Resolve the kind** — read `.agents/<kind>.md`. If it doesn't exist, list
   available kinds and stop.
2. **Resolve the HEAD sha** — `git rev-parse HEAD` on `main` (checks are
   repo-level, not PR-level). Short = first 7.
3. **Run the inspection** per the spec (detect + run the tool). One run, no
   retries. If the tool isn't installed, write `status: error` and say so.
4. **Write the artifact** to `.checks/<kind>/<short_sha>.md` per the spec's
   schema. Newest-first by `generated`.
5. **Report** a one-line summary in chat (kind, status, counts) + the artifact
   path.

## Hard rules

1. **Report only.** Checks never delete code or edit source. Cleanup is a
   follow-up `/ticket` (usually `horizon: next` / `future`) → PR.
2. **Cadence, not per-commit.** Don't wire `/check` into CI as a blocking gate;
   it's a standing-hygiene scan, not a PR gate. (Use `/code-review` for gates.)
   **No scheduler ships with the template** — run it on demand, or add a host
   cron / dedicated scheduled CI job yourself if you want a fixed cadence.
3. **One run per invocation.** Flaky/partial results are reported honestly, not
   retried to green.

## What this is NOT

- Not `/code-review` (per-PR, six-axis, gating). Checks are repo-wide + advisory.
- Not a scheduler. Trigger it yourself or via host cron; the skill just runs the
  inspection and writes the artifact.
