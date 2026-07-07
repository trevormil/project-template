# Capability modules

Plug-and-play production capabilities seeded into repos, managed from the TerMinal
Admin tab, and wired into the software factory. Registry data: `modules.json`
(types in `registry.d.ts`). Seed engine: `seed-module.sh`. Each module has four
faces: **seed / detect / surface / automate**.

## Automation model — deterministic first, cheapest model only for judgment

Seeded automations (the `automate.schedules` cron agents) must be **as deterministic
and as cheap as possible**:

1. **Default: script-first `.agents/<id>.sh` — no model at all.** A check→ticket task
   (health probe, coverage threshold, api-docs drift diff, deploy rollout status) is
   pure shell: run the check, compare to a threshold/diff, and file a ticket with
   `terminal-cli ticket "<title>" "<body>"`. See `health/seed/.agents/health.sh` for
   the exemplar. No LLM engine is invoked for these.
2. **Only reach for a model when the task genuinely needs judgment** (e.g. clustering
   free-text feedback into themes, summarizing a novel failure). Then use the
   **cheapest capable model** — route through the near-free tier (`or-agent` /
   `outsource` skill), never the top model. This mirrors the global downgrade gate:
   default is deterministic; a model is earned only by a real judgment requirement.
3. **Everything is disabled by default.** Seeding writes the schedule inert
   (`enabled:false`, no launchd plist). The user toggles it on from the Admin panel.

Rule of thumb: if a check has a machine-checkable pass/fail, it is a `.sh` with zero
model cost. Reserve model spend for the rare automation that must interpret unstructured
input — and even then, the cheapest one.
