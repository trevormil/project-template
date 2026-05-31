---
name: ticket
description: "Create and manage in-repo backlog tickets (markdown files with YAML frontmatter under backlog/). Allocates an id atomically, writes backlog/NNNN-slug.md, lists/updates/closes tickets. Self-bootstrapping, portable. Use when the user says /ticket, asks to file/list/close, or describes work that should be tracked."
---

# /ticket — In-repo backlog tickets

In-repo markdown tickets at `backlog/NNNN-slug.md` — versioned with the
code, no external service.

## Fast path: TerMinal MCP tools (skip the rest if available)

When the `terminal-harness` MCP server is registered (ships with TerMinal,
installs via Settings), use these instead of reading sections below:

- **`file_ticket({repo, title, body?, type?, priority?, status?, source?})`** —
  allocates next id, writes frontmatter, returns `{slug, id, path}`.
- **`update_ticket({slug, status?, priority?, appendPrUrl?, removePrUrl?})`** —
  whitelisted mutation, auto-bumps `updated:`.
- **`list_tickets({repo?, status?, type?})`** / **`get_ticket({slug})`**.
- **`set_run_outcome({runId: $TERMINAL_RUN_ID, outcome: 'ticket-filed'})`** —
  call after filing when running as a scheduled / `/bg` agent (skip when
  interactive — no TERMINAL_RUN_ID).

Saves ~7k tokens vs reading SKILL.md + EXAMPLE.md. The thinker work
(when to file, type/priority judgment, drafting ACs) still belongs to
you. Shell-helper path below is the fallback when MCP isn't installed.

---

## Where tickets live

`<repo-root>/backlog/NNNN-kebab-slug.md`. Schema: [`EXAMPLE.md`](./EXAMPLE.md).
Counter at `backlog/.next-id`.

## Helper scripts (carried by this skill)

```bash
ROOT="$(git rev-parse --show-toplevel)"
SKILL="$ROOT/.claude/skills/ticket"

"$SKILL/bin/next-ticket-id"      # atomically allocate next id
"$SKILL/bin/tickets"             # list all
"$SKILL/bin/tickets open"        # by status
"$SKILL/bin/tickets open high"   # status + priority
"$SKILL/bin/tickets future"      # by horizon
```

`next-ticket-id` uses an `mkdir` lock (parallel-safe, no `flock`) and
bootstraps `backlog/` if missing. Both must be executable.

## Routing

- **Create** ("file a ticket", "/ticket <desc>") → §Create
- **List** ("what's open", "future ideas") → `bin/tickets [status] [priority] [horizon]`
- **Update / close** ("close #42", "link the MR") → §Update

---

## Create a ticket

### 1. Gather the facts

Infer from context; ask once only if genuinely unclear.

- **Title** — short, action-oriented ("Add rate limit to signaling join").
- **Type** — `bug` | `feature` | `security` | `docs` | `dx` | `testing` | `ux` | `performance`.
- **Priority** — `critical` | `high` | `medium` | `low`. `medium` is a fine default; say so.
- **Horizon** — `now` | `next` | `future`. Scope/timeline, orthogonal to priority. Default `now`.
  `/code-review` and `/session-end` follow-ups are usually `future` or `next`.
- **Source** — `manual`, `audit`, `feedback`, agent name (`code-review`), or a ref.
- **Refs** (optional) — plan unit IDs (`U10`), ADRs (`ADR-0002`), doc paths.

### 2. Allocate an id

```bash
id=$("$(git rev-parse --show-toplevel)/.claude/skills/ticket/bin/next-ticket-id")
```

Never hand-edit `.next-id` — use the script.

### 3. Write the file

Path: `backlog/<id>-<kebab-slug>.md` (slug ≤ 6 words).

```yaml
---
id: <int, matches filename prefix>
title: "<title>"
status: open
priority: <critical|high|medium|low>
horizon: <now|next|future>
hitl: <true|false>
type: <bug|feature|security|docs|dx|testing|ux|performance>
source: <where it came from>
created: <YYYY-MM-DD>
updated: <YYYY-MM-DD>
prs: []
refs: []
---
```

Body (prose goes **after** the closing `---`):

```markdown
## Description
<2–4 sentences: what's the problem/feature, why it matters.>

## Acceptance criteria
- <Concrete, testable bullet>

## Design notes
<Optional: approach, constraints, gotchas.>

## Repro
<Bugs only.>
```

### 4. If it needs a human, raise a HITL item separately

Tickets track work; HITL is for human-only blockers (decisions, approvals,
creds, OAuth/browser flows). Raise to the global inbox (CLAUDE.md [4.2]):

```bash
.claude/bin/hitl "<title>" "<exact action + any url/options>"
```

Lead with the action; include the url. The HITL helper is append-only from the
agent side: it files the Inbox item, emits activity, and pings Telegram. Do not
edit `~/.config/TerMinal/hitl.json` directly, and do not resolve your own HITL
item. If waiting on the human, query the Inbox/list status or periodically
re-check the original blocker; continue when it no longer blocks. Reserve HITL
for true human-needs — not review feedback or test fails inside a workflow
(those iterate).

If the blocker clears after a ticket was marked `stuck`, update the ticket
status immediately: use `open` when returning it to the queue, or `in-progress`
when actively resuming it. Stale `stuck` status is drift.

### 5. Confirm and stop

Show the path. Don't auto-start the work unless asked.

---

## Update / close

Edit the file directly:
- Change `status:` (`open` → `in-progress` → `closed`; or `stuck` / `icebox`).
- When unblocked, change `stuck` → `open` or `in-progress` immediately.
- Bump `updated:` to today.
- On MR/PR open: add the url to `prs:`. On merge: `status: closed`.
- Prose strictly **after** the closing `---`.

`bin/tickets [status]` to verify.

---

## Quality bar

- **Testable acceptance criteria.** "POST /join returns 429 after 100 req/min", not "looks good".
- **One ticket = one piece of work.** Two unrelated things → two tickets.
- **No speculative tickets.** "Maybe we should..." → doc/learning, not a ticket.

## Porting to a new repo

If bootstrapped from the workflow template, `bootstrap.sh` already
installed it — skip. Standalone:

1. Copy `.claude/skills/ticket/` into the target repo.
2. `chmod +x .claude/skills/ticket/bin/*`.
3. Add `backlog/.next-id.lock` to `.gitignore`.

First call bootstraps `backlog/` + `.next-id`. Commit `backlog/` so the
tracker travels with the code.

## Activity

```bash
.claude/bin/activity ticket-filed "Ticket filed · #<id>" "<title>" --ticket <id>
.claude/bin/hitl "<title>" "<action needed>"  # only for human-only blockers
.claude/bin/activity ticket-closed "Ticket closed · #<id>" "<title>" --ticket <id>
```
