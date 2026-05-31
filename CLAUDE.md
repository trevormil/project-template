# CLAUDE.md — <PROJECT NAME>

<!-- Project-specific guidance, loaded on top of global ~/.claude/CLAUDE.md.
     Don't restate global rules — reference as "global §N". Keep lean. -->

<One-line description.> See [`README.md`](./README.md) and
[`docs/architecture.md`](./docs/architecture.md).

**Status:** <design / building / shipped — one line on where things stand.>

## [1] Operating principles

Global §11 (production-grade always, code is cheap / maintenance is not,
don't trust your internal clock, nothing is static) applies. The loop:

```
/session-start "<goal>"   →  seed live session doc (central state)
   /ticket                →  file/triage as backlog/NNNN-slug.md
   feature branch         →  off main (or off prior PR in a stack)
   implement TDD-first    →  failing test → code → green
   /pr-creation           →  push + open PR, link into ticket
   /code-review           →  Codex review to passing bar (background)
   <human merges>         →  merge to main is HUMAN-ONLY (global §8)
/session-end              →  document, clean up, file follow-ups, close
```

Supporting: `/test-suite`, `/security-scan`, `/check`, `/merge-sync`,
`/document` + `/document-audit`, `/notify`, `/stacked-mr`, `/factory`.

## [2] TDD gate (non-negotiable)

Test-first per global §4. Two enforcement points:

- **Review the RED test before implementing** — it's the spec; a wrong test
  locks in wrong behavior.
- **Adversarial, not green-rigging** — meaningful behavior, real I/O, edge
  cases. Tautologies and over-mocking are worse than no tests. e2e /
  integration tests are first-class.

Enforced mechanically: `/session-start` seeds "write failing test for X"
before "implement X"; `/pr-creation` refuses repos with no test suite;
`/code-review` runs the suite as a hard gate; `/session-end` files a
testing ticket for any new behavior without a test.

## [3] Sessions are central state

Live session doc at `sessions/NNNN-slug/session.md` — goal, context,
checklist, log, decisions, outcomes, follow-ups. Exactly **one active**
at a time. Schema in
[`.claude/skills/session-start/SESSION_EXAMPLE.md`](./.claude/skills/session-start/SESSION_EXAMPLE.md).

`.status.md` (gitignored) is the ephemeral at-a-glance for the developer
managing agents — regenerate with `.claude/bin/status > .status.md`.
Agents refresh it at checkpoints (session start/end, PR open/merge,
needs-you events). Feeds the TerMinal sidebar (`/terminal-widget`).

## [4] Tickets

`backlog/NNNN-slug.md`, managed by `/ticket`. Allocate ids with
`.claude/skills/ticket/bin/next-ticket-id` (never hand-edit `.next-id`).
List with `.claude/skills/ticket/bin/tickets [status] [priority] [horizon]`.
Prose lives **after** the closing `---`, never inside frontmatter.

### [4.1] Status lifecycle (gap-free)

`open` → `in-progress` → `closed`, with `stuck` / `icebox` off-ramps.
Each transition has an owner:

- **`in-progress`** the moment work starts — `/session-start`,
  `/pr-creation`, `/stacked-mr` all set it; manual paths set it yourself.
- **`closed`** only when the PR/MR actually **merges** — `/merge-sync`
  closes it and scrubs the merged url from `prs:`. Never pre-close on
  "PR opened."
- **`stuck`** when blocked after real effort (note why); **`icebox`** when
  deliberately deferred. Don't leave work-in-flight rotting as `open`.

`/session-end` reconciles every touched ticket and sweeps the backlog for
drift; `/merge-sync` runs the same sweep standalone. Goal:
`bin/tickets in-progress` always matches reality.

The **`horizon`** tag (`now` | `next` | `future`) is orthogonal to
priority — `/code-review` and `/session-end` park out-of-scope ideas as
`future`.

### [4.2] Inbox — agents reaching the human

**One GLOBAL inbox**, not per-repo. Any skill/agent in any repo:

```bash
.claude/bin/hitl "<title>" "<action needed>" "<optional detail>"
```

Files to `~/.config/TerMinal/hitl.json` (shown as the TerMinal **Inbox** drawer
with an unresolved count), mirrors to the activity feed, **pings Telegram**
directly. Failed cron runs auto-file one.

Claude/Codex Stop hooks, and Cursor completion flows launched through TerMinal,
can file deterministic completion Inbox items by default. Disable only those
completion items with:

```json
{
  "inbox": {
    "completionHook": false
  }
}
```

in `~/.config/TerMinal/settings.json`. Manual/blocker Inbox filing still works.

Reserve for **true human-needs** — spec forks, approvals, credentials,
OAuth/browser flows, hard blockers. **Not** for review `request-changes`
or test failures inside a workflow — those iterate.

## [5] Branches, PRs/MRs & the forge

**Per-repo forge.** `.claude/bin/forge` prints `github` or `gitlab` (reads
`.claude/forge` override, else detects from origin). Use the matching
CLI + terminology — `gh`/"PR" or `glab`/"MR". Mapping:
[`.agents/forge.md`](./.agents/forge.md). Self-hosted GitLab requires the
`.claude/forge` override.

Always work on a feature branch; **never commit/push to `main`** (global
§8, enforced by `.claude/hooks/block-main-merge.sh`). Final merge is
human-only.

- **Commits:** Conventional Commits (`feat:`/`fix:`/…), one logical
  change, imperative subject ≤ ~70 chars.
- **One PR can close multiple tickets** — batch cohesive tickets; code
  review is the throughput bottleneck. PR body lists `Closes #<a> #<b>`;
  link the PR url into **each** ticket's `prs:`.
- **After merge, reconcile** — run `/merge-sync` (especially after
  `/stacked-mr` batches) to close merged tickets and scrub urls.

## [6] Code review & checks

`/code-review` delegates to Codex, writes one combined review+tests
artifact at `.reviews/<pr>/<sha>.md` (+ `findings.json` /
`suggestions.json`). Contract:
[`.agents/code-review.md`](./.agents/code-review.md).

- **Merge bar:** `verdict: approve` + `test_status: pass` + zero findings
  ≥ medium. Overall score is informational.
- **Run in background** — review is ~4 min; fire async, do other work.
  Reviewer files out-of-scope items as `horizon: future` tickets.
- **`/stacked-mr` batches review** — no per-PR review while building;
  one end-of-stack pass fans out `/code-review` per PR in parallel
  (each in its own worktree). See the contract's "Batch stacked-MR
  review" section.

**Cadence checks** are the other half: `/check <kind>` runs a repo-level
inspection (dead-code, dep-drift) on a cadence, writing dated artifacts
to `.checks/<kind>/<sha>.md`. Each kind is a contract at
`.agents/<kind>.md`. Checks are **advisory** — they report; cleanup
becomes a ticket.

## [7] Documentation & knowledge base

Sidecar `.md` under `docs/` (global §7): `decisions/` (append-only ADRs),
`architecture.md` (evergreen, edit-in-place), `runbooks/`, `learnings/`.
Capture with `/document`, rot-check with `/document-audit`. `/session-end`
is the main moment things get written.

## [8] Doc anchoring

Long docs (session docs, ADRs, architecture) stay **greppable**:

- Heading anchors: `## [1] Title`, `### [1.2] Title`. Numbers are
  **stable ids, not ordinals** — append new ones, never renumber.
- Doc code in frontmatter: `anchor: SES-0007` / `ADR-0003` / `ARCH`.
- Grep: `grep -n "\[3.1\]" path/to/doc.md`. Cross-doc: `SES-0007#3.1`.

Short tickets don't need it.

## [9] When picking back up

<!-- Steps to resume after a context switch — saves rediscovering tribal
     knowledge. Example: -->

1. <e.g. `docker compose up -d`>
2. <e.g. reset local DB / apply migrations>
3. <e.g. `bun test`>
4. `/session-start "<goal>"` or resume the `active` session.

## [10] Autonomous / AFK modes

- **`/notify`** — on-demand two-way Telegram bridge for AFK sessions
  (depends on `~/.claude` telegram creds).
- **`/stacked-mr`** — overnight: stacks PRs (each off the prior tip),
  TDD per ticket, no per-PR review during build, then one batch review
  pass at the end (one review per PR, each in its own worktree). No
  human merge until you review the stack in the morning.
- **`/factory`** — perpetual loop around `/stacked-mr`: each iteration
  `/merge-sync` → build stack → batch-review → handle verdicts →
  optionally refill via `--discover` → repeat. Parks HITL on
  decisions/blockers. Pure orchestration; never changes the bar or
  merges to main. Bounded by backlog.

## [11] Conventions

- Tooling: `bun` / `bunx`; pin deps; commit lockfile (global §5, §10).
- Style/errors/types/barrels/file-org: global §6.
- Frontend: Tailwind (global §9).
- <Project-specific conventions here. Keep beyond-spec ambition in check
  against explicit spec constraints.>

## [12] Project specifics

<!-- Domain context, substrate, external services, runbooks,
     "don't re-derive" facts. Subsections [12.1], [12.2], … as needed. -->

## [13] Activity feed

Surface every workflow milestone to the shared feed so it shows up live
in TerMinal:

```bash
.claude/bin/activity <kind> "<title>" ["<detail>"]
```

`kind` ∈ `ticket-filed` · `pr-verdict` · `session-start` · `session-end` ·
`agent-run` · `info` · `error`. Exit-0 safe (never breaks workflow);
derives repo context from git. **Every skill** that hits a milestone emits
one event.
