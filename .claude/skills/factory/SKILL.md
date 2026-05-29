---
name: factory
description: "Autonomous software-factory orchestrator. The master loop that continuously turns the backlog into REVIEWED, merge-ready PRs with no human in the loop — picks the next ticket, builds it TDD-first on a stacked branch, runs /code-review and auto-applies the findings until it hits the merge bar, then stacks the next on top. NEVER merges to main/master (the human gate is the point). Parks at HITL on decisions/blockers, respects a budget, and can optionally discover new work. It does not reinvent ticketing/building/review — it drives every other skill. Use when the user runs /factory or asks to run the factory / autonomously work the backlog / build the whole queue."
---

# /factory — autonomous software-factory orchestrator

The master loop. Every other skill is a **tool** it calls; `/factory` is the thing
that sequences them continuously and gates on quality. It does **not** reinvent
ticketing, building, or review — it drives `/session-start`, `/ticket`,
`/pr-creation`, `/test-suite`, `/code-review`, `/security-scan`, `/check`,
`/merge-sync`, `/document`, `/notify`, and the stacked-MR model.

Its output is a stack of **reviewed, green, merge-ready PRs**. **The human merges.**
The factory never touches `main`/`master` (global §8, hook-enforced) — that gate is
the whole design: full autonomy *up to* merge, a human *at* merge.

> Relationship to `/stacked-mr`: they share the stacking core. `/stacked-mr` is the
> simple "build one overnight stack" entry. `/factory` is the continuous, gated,
> budgeted **superset** — it adds the autonomous review→fix→re-review-to-the-bar
> loop, budget/safety caps, HITL parking, and (optional) self-feeding discovery.

## [1] Invocation

```
/factory                      # work the now/next backlog by priority, to the bar
/factory "vault + payments"   # scope to a goal (only matching tickets)
/factory --budget 2m          # stop after ~2M output tokens (default: confirm a cap first)
/factory --max-stack 12       # cap stack depth (default 20)
/factory --max-fix 3          # max review→fix cycles per PR before "stuck" (default 3)
/factory --discover           # when the queue empties, run discovery agents to file more work
```

This is an AFK mode: **arm `/notify`** at kickoff, ping at checkpoints and on every
HITL/blocker/stop. Keep a live ledger in the session doc; refresh
`.claude/bin/status > .status.md` after each ticket.

## [2] The loop

```
preflight  →  reconcile  →  ┌─ pick → build → review→fix→bar → stack ─┐  →  handoff
                            └──────────── repeat ─────────────────────┘
```

0. **Preflight.** `/session-start` to seed the live doc + context. Confirm the repo
   is clean and the suite is green at HEAD (if red, fix or stop — never build on red).
   Confirm a budget cap (see [6]); arm `/notify`.
1. **Reconcile.** Run `/merge-sync` so the backlog matches reality (close merged,
   fix drift) before picking work — see CLAUDE.md [4.1].
2. **Loop** until a stop condition ([9]):
   - **Pick** the next ticket ([5]). None left → discovery ([8]) or stop.
   - **Build** it: cut a stacked branch off the current tip (base = parent branch),
     `/pr-creation` (TDD-first), push, open the PR, link it into the ticket. Set the
     ticket `in-progress`.
   - **Review → fix → bar** ([3]): `/code-review`; if `request-changes`/`blocked`,
     apply each finding's fix prompt, push, re-review — repeat until the bar OR
     `--max-fix` cycles. Can't reach the bar → mark the ticket `stuck`, park HITL,
     move on.
   - **Stack** the next ticket on this PR's tip. If a fix changed a lower tip,
     **restack children** (`git rebase --onto …` + `--force-with-lease` to feature
     branches only).
3. **Handoff** ([10]) when the loop stops.

## [3] Quality gates (non-negotiable) — the trust backbone

The factory's autonomy is only safe because the gate is absolute:

- **`/code-review` to the bar:** `verdict: approve` + `test_status: pass` + **zero
  findings ≥ medium**. The bar is **never lowered** to make progress.
- **Auto-fix loop:** apply each finding's copy-pasteable fix prompt, re-run the
  suite, re-review. Up to `--max-fix` cycles per PR.
- **Red tests anywhere → stop that line.** Never push past red; fix it or mark
  `stuck`.
- **Security floor:** `/security-scan` feeds the Security axis; a leaked secret is
  an automatic hard stop (rotate first).
- **Out of cycles → `stuck` + HITL,** not a lowered bar. A PR below the bar is
  parked for a human, never advanced.

## [4] Stacking — the human gate is preserved

Uses the `/stacked-mr` model: branch N+1 is cut from branch N's tip, each PR's base
is its parent, so each review sees only that PR's delta. The factory **never merges**
— it produces a reviewed, green stack and stops at "ready for human merge." The human
merges bottom-up; `/merge-sync` then reconciles tickets. (Force-push only to feature
branches, only for restacking, only `--force-with-lease`.)

## [5] Picking work

From the in-scope set (the goal, else the backlog):

- **Horizon:** `now` before `next`; skip `future` unless scoped to it.
- **Priority:** `critical` → `high` → `medium` → `low`.
- **Skip:** `hitl` (needs a human), `stuck`, `icebox`, `closed`, and tickets whose
  declared dependencies aren't merged yet (don't build on an unmerged dependency).
- Set each picked ticket `in-progress` + bump `updated:` (CLAUDE.md [4.1]).

## [6] Budget & safety

An unattended loop must not run away — on tokens, time, or risk:

- **Budget cap** (`--budget`, tokens/$/time): confirm one at kickoff if not given;
  track spend; stop **cleanly** at the cap with a full handoff (never mid-PR if
  avoidable).
- **Caps:** `--max-stack` (depth), `--max-fix` (cycles/PR).
- **Destructive or cost-bearing actions are NEVER autonomous** — deploys, prod data,
  spending, new paid deps, anything irreversible → park HITL ([7]).
- Surface spend + counts in the handoff.

## [7] HITL — when to ask

Park a HITL ticket (`/ticket` with `hitl: true` + an `## Action needed` section) and
ping `/notify`, then continue independent work if any (else pause), when the factory
hits:

- an **ambiguous spec** or a **design fork** it shouldn't decide unilaterally,
- a **destructive/cost-bearing** action ([6]),
- a ticket it **can't get to the bar** in `--max-fix` cycles,
- a dependency on a **human-only action** (approve a merge, provision creds, an
  OAuth/browser flow, a product call).

The human resolves these from the HITL tab; the factory picks them up on its next
pass once they're unblocked.

## [8] Discovery (optional — `--discover`)

When the in-scope queue empties, instead of stopping, run the discovery agents
(deep-audit / security-sweep / `/check` kinds) to **file new tickets** — the
"what to build next" engine — then resume the loop. **Off by default**: don't invent
infinite work unless asked. New tickets land as `open` for the next pass; the factory
does not silently expand its own scope.

## [9] Stop conditions

- In-scope queue exhausted (and no `--discover`).
- Budget / `--max-stack` reached.
- A true blocker needing a human decision (parked HITL; pause that line).
- One ticket fails to reach the bar after `--max-fix` → mark `stuck`, move on (don't
  burn the run on one ticket).
- The user says stop / "I'm back."

## [10] Morning handoff

Produce a **stack summary** in dependency order — for each: PR url, ticket id, base
branch, latest verdict, test counts, and any `stuck`/HITL flags:

```
Factory run · 7 PRs built · 6 at the bar · 1 stuck · ~1.4M tokens
  #1  0012-vault-create    base:main              approve  ✅ 9/9
  #2  0013-vault-spend     base:0012-vault-create approve  ✅ 12/12
  #3  0014-payment-link    base:0013-vault-spend  stuck    — couldn't pass auth test (HITL #0021)
  ...
The human merges bottom-up; run /merge-sync after.
```

The human merges bottom-up; `/merge-sync` reconciles. Capture anything learned via
`/document`, then `/session-end`.

## Hard rules

1. **Never merge to main/master** (global §8, hook-enforced). The stack waits for the
   human. This is the point of the factory, not a limitation.
2. **Never lower the review bar** to make progress. Below-bar work is parked, not shipped.
3. **Destructive / cost-bearing actions → HITL,** never autonomous.
4. **Respect the budget;** stop cleanly, hand off, don't run away.
5. **TDD-first** on every ticket — failing test before code.
6. **Every checkpoint emits activity** (and `/notify` on HITL/blockers) so the run is
   observable live.

## What this is NOT

- **Not a merge bot.** It builds + reviews to the bar; humans merge.
- **Not a bar-skipper.** The gate is absolute; that's what makes the autonomy safe.
- **Not a replacement for `/stacked-mr`** on simple jobs — `/stacked-mr` is the
  one-overnight-stack entry; `/factory` is the continuous, gated, budgeted, optionally
  self-feeding superset.
- **Not a scope inventor.** Without `--discover` it only works existing tickets.

## Activity

Emit feed events at each checkpoint (the run is watched live in TerMinal):

```bash
.claude/bin/activity info "Factory started · <scope>" "budget <cap>"
# (per ticket: /pr-creation emits pr-opened, /code-review emits the verdict)
.claude/bin/activity blocked "Factory · HITL · #<id>" "<why / options>"
.claude/bin/activity task-complete "Factory run complete · <N> PRs" "<X at bar, Y stuck>"
```
