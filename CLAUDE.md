# CLAUDE.md — <PROJECT NAME>

<!-- Fill the placeholders below. This file is project-specific guidance that
     loads ON TOP of the global ~/.claude/CLAUDE.md (§1–11). Don't restate the
     global rules here — reference them as "global §N". Keep this lean. -->

<One-line description of what this project is.> See [`README.md`](./README.md)
and [`docs/architecture.md`](./docs/architecture.md).

**Status:** <design / building / shipped — one line on where things stand and
what to pick up next.>

## Operating principles (read first)

Mindset rules that override convenience everywhere in this workflow:

- **Production-grade, always.** Never assume a codebase is a demo, an
  assignment, a prototype, or throwaway — treat every repo as if it ships to
  production at scale. Security, architecture, and tests are first-class on
  every change, however small. "It's just a demo" is never a reason to cut a
  corner. (This is why `/code-review` scores at enterprise rigor.)
- **Don't trust your internal clock.** Your sense of how long things take is
  calibrated on *human* pace and is wrong for AI work — a task training data
  calls "a day" is often minutes here. So: (1) never pad scope or skip work
  because you assume you're short on time; you almost always have more room than
  it feels. (2) When timing genuinely matters, ground yourself in reality —
  check the real clock (`date`) and measure actual elapsed time rather than
  estimating. Don't claim something took / will take a duration you didn't
  measure.
- **Code is cheap; maintenance is not.** Generating code is nearly free now, so
  the bottleneck (and the risk) is sprawl — features, abstractions, and config
  that accrete faster than anyone can maintain, secure, or reason about. Resist
  the "Winchester House" failure mode: every addition must earn its keep
  (global §2). Prefer deleting to adding; the smallest thing that satisfies the
  ticket wins.
- **Nothing is static — docs, conventions, and the workflow itself are live.**
  This template is a starting point, not a frozen spec. If a skill is wrong or a
  step is missing, upgrade it; if a convention stops fitting, change it; if a doc
  drifts from reality, update it in place (ADRs evolve via supersede — see §7);
  if the core workflow needs to change, change it. Always be experimenting —
  assume nothing here is frozen, including this file. The cost of a stale
  convention is paid on every future task. (Global §11.)

The loop, in order. Everything is tracked **in this repo** — no external tracker,
no central dashboard.

```
/session-start "<goal>"   →  seed the live session doc (central state)
   /ticket                →  file/triage work as backlog/NNNN-slug.md
   feature branch         →  off main (or off the prior PR in a stack)
   implement TDD-first    →  failing test → code → green
   /pr-creation           →  push + open PR via gh, link PR into the ticket
   /code-review           →  Codex review to the passing bar (run in background)
   <human merges>         →  merge to main is HUMAN-ONLY (global §8)
/session-end              →  document, clean up, file follow-ups, close the doc
```

Supporting skills: `/test-suite` (cheap chat-only test run between commits),
`/security-scan` (deterministic security floor), `/check` (cadence repo
inspections — dead-code etc.), `/merge-sync` (close tickets + scrub urls after
the human merges), `/document` + `/document-audit` (knowledge base), `/notify`
(on-demand AFK Telegram bridge), `/stacked-mr` (autonomous overnight PR
stacking).

## [2] TDD gate (non-negotiable)

Every behavior change is **test-first**: write the failing test, watch it fail
*for the right reason*, then write the code to make it pass (global §4).

Two rules that make TDD real rather than theater:

- **Review the test before you implement.** Once the RED test is written and
  before any production code, confirm it actually pins the ticket's acceptance
  criteria — the test is the spec. A wrong/weak test locks in the wrong
  behavior.
- **Be adversarial — never write a test just to go green.** A test rigged to
  pass is the *opposite* of the goal: it manufactures false confidence. No
  tautologies, no asserting the implementation's current output back at itself,
  no over-mocking the unit under test, no asserting trivia. Tests must assert
  *meaningful* behavior — real inputs/outputs, edge cases, and failure modes —
  and would catch a genuine regression. A green suite of weak tests is worse
  than no tests. **Automated e2e/integration tests** (Playwright, API/contract
  tests) are first-class here: they prove the feature is actually wired and
  stays correct end-to-end, not just that a function returns a value.

Enforced socially and mechanically:

- `/session-start` seeds checklists as "write failing test for X" *before*
  "implement X".
- `/pr-creation` will not proceed against a repo with no test suite — it stops
  and files a ticket to add one.
- `/code-review` runs the suite as its **gate** (red tests → `blocked`, no
  exceptions) and flags any new behavior shipped without a test as a
  high-severity finding even when the suite is green.
- `/session-end` verifies new behavior has tests and files a testing ticket for
  any gap rather than papering over it.

## [3] Sessions are central state

A work session's live doc at `sessions/NNNN-slug/session.md` is the single source
of truth for in-flight work — goal, seeded context, checklist, log, decisions,
outcomes, follow-ups, documentation. Exactly **one session is `active`** at a
time. Schema: [`.claude/skills/session-start/SESSION_EXAMPLE.md`](./.claude/skills/session-start/SESSION_EXAMPLE.md).
Start with `/session-start`, close with `/session-end` (which is a real
15–30 min closing process, not a quick wrap).

**Live status for the human (`.status.md`).** Session docs are the *committed,
durable* state; `.status.md` (gitignored) is the *ephemeral* at-a-glance
snapshot for the developer **managing agents** in this repo — what needs you
(HITL/blockers), backlog counts, active session, recent review verdicts.
Regenerate it deterministically from local state any time with
`.claude/bin/status > .status.md`; agents refresh it at checkpoints
(session start/end, after opening/merging PRs, when something starts needing
you). It can also feed a TerMinal sidebar widget (see
`/terminal-widget`).

## [4] Tickets

In-repo markdown tickets at `backlog/NNNN-slug.md`, managed by `/ticket`.
Allocate ids atomically with `.claude/skills/ticket/bin/next-ticket-id` (never
hand-edit `.next-id`). List with `.claude/skills/ticket/bin/tickets [status]
[priority] [horizon]`. Prose lives **after** the closing `---`, never inside the
frontmatter delimiters.

### [4.1] Status lifecycle (keep it gap-free)

A ticket's `status` must always reflect reality. The lifecycle is
**`open` → `in-progress` → `closed`** (with `stuck` / `icebox` as off-ramps), and
each transition has an owner — **never leave a worked ticket stale**:

- **`open` → `in-progress`** the moment work actually starts on it:
  `/session-start` sets every ticket it commits to this session to
  `in-progress`; `/pr-creation` sets it `in-progress` before the first commit;
  `/stacked-mr` sets it when it cuts the branch. If you start a ticket by any
  other path, set it yourself.
- **`in-progress` → `closed`** only when its PR/MR actually **merges** —
  `/merge-sync` does this (and scrubs the merged URL from `prs:`). Agents never
  pre-close on "PR opened"; the human merges, then reconciliation closes.
- **`stuck`** when blocked after reasonable effort (note why); **`icebox`** when
  deliberately deferred. Both are explicit, not a ticket left rotting in
  `in-progress`.

**Reconciliation is periodic, not hopeful.** `/session-end` reconciles every
ticket touched in the session **and** sweeps the backlog for drift (merged-but-
open, in-progress with no open PR, long-stale `open`). The same sweep runs
standalone via `/merge-sync` anytime PRs have landed. The goal: at any moment,
`bin/tickets in-progress` is exactly the work actually in flight.

The **`horizon`** tag (`now` | `next` | `future`) is orthogonal to priority —
it's the scope/timeline lens. `future` is where `/code-review` and `/session-end`
park out-of-scope extensions and ideas, so the backlog separates "do now" from
"someday" at a glance: `bin/tickets future`.

The **`hitl`** flag (`true` | `false`) marks **human-in-the-loop** tickets — work
that needs a manual action only you can take (approve a merge, provision creds, a
browser/OAuth flow, a product call). Filing one sends a Telegram ping describing
the action; list them with `bin/tickets hitl`. HITL tickets carry an
`## Action needed` section.

## [5] Branches, PRs/MRs & the forge

**Forge is per-repo — GitHub or GitLab.** Resolve with `.claude/bin/forge`
(prints `github` or `gitlab`; reads the `.claude/forge` override, else detects
from the origin remote). Use the matching CLI + terminology — `gh`/"PR" or
`glab`/"MR"; full command mapping in
[`.agents/forge.md`](./.agents/forge.md). To switch a repo's forge, write
`github` or `gitlab` to `.claude/forge` (required for self-hosted GitLab, whose
host the detector can't infer).

Always work on a feature branch; **never commit or push to `main`** (global §8 —
enforced by `.claude/hooks/block-main-merge.sh`). The final merge is human-only.

- **Commits:** [Conventional Commits](https://www.conventionalcommits.org)
  (`feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:` …). One logical
  change per commit; subject in the imperative, ≤ ~70 chars.
- **One PR can close multiple tickets.** A ticket is not 1:1 with a PR — batch
  cohesive tickets into one reviewable PR (code review is the throughput
  bottleneck). The PR body lists `Closes #<a> #<b>`; link the PR url into **each**
  ticket's `prs:`.
- **After merge, reconcile.** Since the human merges, run **`/merge-sync`**
  afterward (especially after a `/stacked-mr` batch) to set the merged tickets
  `closed` and scrub the merged PR urls from `prs:` (the list is for *active*
  tracking; git history keeps the trail).

## [6] Code review & checks

`/code-review` delegates to Codex and writes one combined review+tests artifact
**in-repo** under `.reviews/<pr>/<sha>.md` (+ `findings.json` / `suggestions.json`).
Contract: [`.agents/code-review.md`](./.agents/code-review.md).

- **Merge bar:** `verdict: approve` + `test_status: pass` + zero findings at
  severity ≥ medium. The overall score is informational, not a gate.
- **Run it in the background.** Review is the most common dev-speed bottleneck
  (~4 min). Fire it async and go do other useful work; don't sit blocked. The
  reviewer can also file out-of-scope follow-ups as `horizon: future` tickets.
- **In `/stacked-mr` mode, review is batched.** Don't review per-PR while
  building the stack; defer all reviews to one end-of-stack pass that fans out a
  `/code-review` per PR in parallel (each in its own worktree). See the contract
  ([`.agents/code-review.md`](./.agents/code-review.md) → "Batch stacked-MR
  review") and the `/stacked-mr` skill.

**Cadence checks** are the other half: `/check <kind>` runs a *repo-level*
inspection (dead-code, dep-drift) on the whole tree, on a cadence — not per
commit — and writes a dated artifact to `.checks/<kind>/<sha>.md`. Each kind is
a contract at `.agents/<kind>.md` (copy `dead-code.md` to add one). Checks are
**advisory** — they report; cleanup becomes a ticket, never an auto-edit.

## [7] Documentation & knowledge base

Sidecar `.md` under `docs/` (global §7): `decisions/` (append-only ADRs),
`architecture.md` (evergreen, edit-in-place), `runbooks/`, `learnings/`. Capture
with `/document`, rot-check with `/document-audit`. `/session-end` is the main
moment documentation gets written — nothing learned should be lost.

## [8] Doc anchoring convention

Long docs (session docs, ADRs, architecture) must stay **greppable**. Every
heading carries a bracketed anchor; the doc declares a short `anchor:` code in
frontmatter for cross-doc references.

- **Heading anchors:** `## [1] Title`, sub `### [1.2] Title`, deeper
  `#### [1.2.3] Title`. Numbers are **stable ids, not ordinals** — append new
  ones, don't renumber existing sections (that would break references).
- **Doc code:** `anchor: SES-0007` / `ADR-0003` / `ARCH` / `RB-deploy` /
  `LRN-<slug>` in frontmatter.
- **Grep a part:** `grep -n "\[3.1\]" path/to/doc.md`.
- **Reference across docs:** `SES-0007#3.1`, `ADR-0003#2`, `ARCH#4`.

Apply it to every doc long enough that someone would want to jump to a specific
part. Short tickets don't need it.

## [9] When picking back up

<!-- Fill this in once the project has a runnable loop. The exact steps to
     resume work after a context switch — saves rediscovering tribal knowledge.
     Example: -->

1. <e.g. start the backing service: `docker compose up -d`>
2. <e.g. reset local DB / apply migrations>
3. <e.g. run the test suite to confirm green: `bun test`>
4. `/session-start "<goal>"` or resume the `active` session in `sessions/`.

## [10] Autonomous / AFK modes (on-demand)

- **`/notify`** — on-demand two-way Telegram bridge for AFK sessions (off by
  default; depends on machine-level telegram scripts/creds in `~/.claude`).
- **`/stacked-mr`** — autonomous overnight mode: stacks PRs (each branch off the
  prior tip, base = parent branch), TDD per ticket, built **without per-PR
  review**, then **one batch review pass** at the end that reviews every PR in
  parallel (one review per PR, each in its own worktree) to the bar. **No human
  merge** until you review the whole stack in the morning. Produces ~N stacked PRs.
- **`/factory`** — the continuous orchestrator: the perpetual **loop around
  `/stacked-mr`**. Each iteration `/merge-sync` (reconcile) → run a stacked-mr pass
  (build a stack → batch-review to the bar → handle verdicts) → optionally refill
  the queue with discovery agents (`--discover`) → repeat, parking **HITL** on
  decisions/blockers, until the backlog is dry or you stop. Pure orchestration — it
  reuses every skill and **never changes the bar** or **merges to main/master**
  (the human gate is the point). No budget — bounded by the backlog + you.

## [11] Conventions

- Tooling: `bun` / `bunx`; pin deps; commit the lockfile (global §5, §10).
- Style/error-handling/types/barrels/file-org: global §6.
- Frontend: Tailwind (global §9).
- <Any project-specific conventions a newcomer needs go here. Keep beyond-spec
  ambition in check against explicit spec constraints.>

## [12] Project specifics

<!-- The stuff that's unique to THIS project: domain context, substrate,
     external services, key runbooks, "don't re-derive" facts, gotchas. Add
     subsections [12.1], [12.2], … as needed. -->

## [13] Activity feed

Surface every meaningful workflow milestone to the shared **activity feed** so
it shows up live (and as a desktop notification) in TerMinal. One call,
at the moment it happens:

```bash
.claude/bin/activity <kind> "<title>" ["<detail>"]
```

`kind` ∈ `ticket-filed` · `pr-verdict` · `session-start` · `session-end` ·
`agent-run` · `info` · `error`. It's exit-0 safe (never breaks the workflow) and
derives repo context from git. **Engrain it**: any skill that hits a milestone —
filing a ticket, finishing a review, opening a PR/MR, starting/ending a session,
running an agent — emits one event. New skills follow the same rule.
