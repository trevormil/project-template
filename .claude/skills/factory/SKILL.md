---
name: factory
description: "Continuous autonomous orchestrator — the perpetual loop around /stacked-mr. /stacked-mr does ONE pass (build a stack → batch-review to the bar → hand off); /factory keeps doing it: reconcile with /merge-sync, run a stacked-mr pass, optionally refill the queue with discovery agents, repeat — parking HITL on decisions/blockers, until the backlog is dry or you stop. NEVER merges to main/master (the human gate is the point). It reuses every skill; it does not reimplement build or review. Use when the user runs /factory or asks to run the factory / continuously / autonomously work the backlog until it's empty."
---

# /factory — continuous autonomous orchestrator

The perpetual loop. `/stacked-mr` is the **primitive** — one pass: build a stack of
PRs, batch-review them to the bar at the end, hand off. `/factory` is the **loop
around it**: reconcile, run a stacked-mr pass, (optionally) refill the queue, repeat
— parking HITL on anything that needs a human, until the backlog is dry or you stop.

It **reuses** every skill — especially `/stacked-mr` (the build + batch-review
engine), `/merge-sync` (reconcile), the discovery agents (refill), and `/notify`
(AFK). It adds **no new build/review logic and no new quality gate** — the bar lives
in `/stacked-mr`. Output is reviewed, merge-ready stacks; **the human merges**
(global §8, hook-enforced).

## [1] Invocation

```
/factory                      # loop the now/next backlog until it's dry
/factory "vault + payments"   # scope to a goal (passed through to each pass)
/factory --discover           # when the queue empties, refill from discovery agents instead of stopping
/factory --max-stack 12       # cap each stacked-mr pass's depth (default: stacked-mr's default)
```

AFK mode: **arm `/notify`** at kickoff; ping at each pass boundary and on every
HITL/blocker/stop.

## [2] The loop

```
   ┌─► /merge-sync (reconcile)
   │        │
   │        ▼
   │   /stacked-mr pass  (build the stack → batch-review to the bar → handle verdicts)
   │        │
   │        ▼
   │   in-scope queue empty?
   │     ├─ no  ──────────────────────────────► loop
   │     └─ yes → --discover? ─ yes → file work ─► loop
   │                          └ no ────────────► handoff ([6])
   └────────────────────────────────────────────┘
```

1. **Reconcile.** Run `/merge-sync` so the backlog is truthful — closes any PRs the
   human merged since the last pass and fixes status drift (CLAUDE.md [4.1]).
2. **Run a `/stacked-mr` pass** over the in-scope queue. That skill owns the
   mechanics: build the stack (each branch off the prior tip, no per-PR review),
   then one batch review of all PRs to the bar, then handle verdicts (fix +
   restack). `/factory` does not duplicate any of this.
3. **Refill or finish.** If the in-scope queue is now empty: with `--discover`, run
   the discovery agents to file new tickets ([5]) and loop; without it, go to
   handoff. If tickets remain, loop.

Across passes the stack keeps growing on the prior (unmerged) tip — the human
typically merges at the end, so reconcile mostly matters at the start of a run and
whenever the human merges mid-run.

## [3] What `/factory` adds vs `/stacked-mr` (and what it does NOT)

| | `/stacked-mr` | `/factory` |
|---|---|---|
| Build + batch-review to the bar | ✅ (owns it) | reuses it |
| Run shape | one pass, then stop | continuous loop |
| Reconcile first (`/merge-sync`) | — | ✅ each iteration |
| Refill the queue | — | ✅ optional (`--discover`) |
| Quality bar | defines it | unchanged — never altered |
| Merge to main | never | never |

`/factory` is **purely orchestration** — a loop + reconcile + refill + HITL. It adds
no new way to build or review, and never changes the bar.

## [4] HITL — park and continue

When a pass surfaces something a human must decide — ambiguous spec, design fork, a
destructive/cost-bearing action, a PR that can't reach the bar after stacked-mr's
fix cycles, or a dependency on a human-only action (approve a merge, provision
creds, an OAuth/browser flow) — raise it to the **global HITL inbox** with
`.claude/bin/hitl "<title>" "<action needed>"` (CLAUDE.md [4.2]; this pings the
operator), then continue independent work; pause only if nothing else can proceed.
The human resolves it from the HITL tab; the next loop picks it up once unblocked.
Do **not** raise HITL for review `request-changes` — that's the iterative loop's job.

## [5] Discovery (optional — `--discover`)

When the in-scope queue empties, refill it instead of stopping: run the discovery
agents (deep-audit / security-sweep / `/check` kinds) to file new `open` tickets,
then loop. **Off by default** — `/factory` does not invent infinite scope; without
`--discover` it drains the existing backlog and stops.

## [6] Handoff

Use `/stacked-mr`'s stack summary (PRs in dependency order with verdict, tests, and
any `stuck`/HITL flags), plus a one-line factory tally (passes run, total PRs at the
bar vs stuck). The human merges bottom-up; `/merge-sync` reconciles; capture
learnings via `/document`; close with `/session-end`.

## Hard rules

1. **Never merge to main/master** (global §8, hook-enforced) — the human gate is the
   point of the factory.
2. **Never change the review bar** — `/stacked-mr` owns it; `/factory` only runs more
   passes.
3. **Destructive / cost-bearing actions → HITL,** never autonomous.
4. **Reuse, don't reimplement** — `/factory` calls `/stacked-mr`, `/merge-sync`,
   discovery, `/notify`; it never duplicates build/review logic.
5. **Emit activity + `/notify`** at pass boundaries and on HITL/blockers so the run
   is observable live.

## What this is NOT

- **Not a build/review engine** — it's the loop *around* `/stacked-mr`.
- **Not a merge bot** — humans merge.
- **Not a bar-skipper** — the gate is `/stacked-mr`'s and is absolute.
- **Not a scope inventor** — without `--discover` it only works existing tickets.
- **Not budgeted** — there is no token/cost cap; the run is bounded by the backlog
  (finite unless `--discover`) and by you stopping it.

## Activity

```bash
.claude/bin/activity info "Factory started · <scope>" "looping the backlog"
# each pass: /stacked-mr emits pr-opened + review verdicts per PR
.claude/bin/hitl "Factory blocked · <title>" "<action needed / options>"   # true human-needs → global inbox
.claude/bin/activity task-complete "Factory done · <P> passes · <N> PRs" "<X at bar, Y stuck>"
```
