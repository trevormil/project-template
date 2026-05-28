# CLAUDE.md — <PROJECT NAME>

<!-- Fill the placeholders below. This file is project-specific guidance that
     loads ON TOP of the global ~/.claude/CLAUDE.md (§1–10). Don't restate the
     global rules here — reference them as "global §N". Keep this lean. -->

<One-line description of what this project is.> See [`README.md`](./README.md)
and [`docs/architecture.md`](./docs/architecture.md).

**Status:** <design / building / shipped — one line on where things stand and
what to pick up next.>

## Operating principles (read first)

Two mindset rules that override convenience everywhere in this workflow:

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

## [1] How we work here

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

## [4] Tickets

In-repo markdown tickets at `backlog/NNNN-slug.md`, managed by `/ticket`.
Allocate ids atomically with `.claude/skills/ticket/bin/next-ticket-id` (never
hand-edit `.next-id`). List with `.claude/skills/ticket/bin/tickets [status]
[priority] [horizon]`. Prose lives **after** the closing `---`, never inside the
frontmatter delimiters.

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
  prior tip, base = parent branch), TDD per ticket, code-reviewed to the bar,
  non-blocking pipeline, **no human merge** until you review the whole stack in
  the morning. Produces ~N stacked PRs.

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
