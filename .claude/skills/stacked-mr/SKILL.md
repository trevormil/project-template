---
name: stacked-mr
description: "Autonomous AFK overnight mode. Works a backlog queue as a STACK of PRs (each branch off the prior tip), TDD per ticket, NO per-PR review during build. Run ONE batch review pass at the end that fires /code-review per PR concurrently in isolated worktrees. Human reviews the whole stack in the morning. Use when the user runs /stacked-mr or asks to stack PRs overnight."
---

# /stacked-mr — Autonomous overnight PR stacking

A long-running AFK mode. Branch N+1 is cut from branch N's tip; work keeps
flowing without merging to `main`. The human reviews the whole stack in
the morning and merges bottom-up (global §8).

**Review is batched, not per-PR.** Build the whole in-scope stack without
firing reviews, then run **one batch pass** that fans out `/code-review`
per PR concurrently, each in its own worktree. Two reasons:

- **Speed.** Serial: ~4 min × N PRs. Batched: ~4 min total.
- **No review-vs-build contention.** A review inspects/tests a checkout;
  running one while the builder is editing the same repo contaminates
  results.

Forge-agnostic: this doc says "PR" / `gh`, but stacking is identical on
GitLab — `glab mr create --target-branch <parent>`. Resolve with
`.claude/bin/forge`; mapping in
[`.agents/forge.md`](../../../.agents/forge.md).

## Invocation

```
/stacked-mr "work the vault + payment tickets"  # scoped to a goal
/stacked-mr                                      # work now/next backlog by priority
```

AFK mode: arm Telegram (`/notify`) at kickoff; ping at checkpoints.

## The stacking model

```
main
 └─ 0012-vault-create        (PR #1, base: main)
     └─ 0013-vault-spend     (PR #2, base: 0012-vault-create)
         └─ 0014-payment-link (PR #3, base: 0013-vault-spend)
```

Each PR's **base** is its parent branch, so each diff is just that PR's
delta. `gh pr create --base <parent-branch>` sets this. `/code-review`
resolves base from the PR, so each end-of-stack review sees only the
owning PR's incremental slice.

## Phase 1 — Build the stack (no reviews)

Work the queue ticket-by-ticket. **Do not run `/code-review`** —
deferred to Phase 2.

1. **Pick the next ticket** — from the goal, else backlog by horizon
   (`now`, then `next`) and priority. Skip `future` unless told. Set
   `status: in-progress`.
2. **Cut from the current tip:**
   ```bash
   parent="<previous branch, or origin/main for first>"
   branch="<id>-<slug>"
   git switch -c "$branch" "$parent"
   ```
3. **TDD-first** — failing test → code → green. Commit incrementally.
4. **Sanity + push** — type-check/build, eyeball the diff,
   `git push -u origin "$branch"`.
5. **Open the PR** with `--base "$parent"`:
   ```bash
   gh pr create --base "$parent" --title "<title>" --body "<summary + stack position>"
   ```
   Body notes "Stacked on #<parent-PR>. Part N of <goal> stack." Link
   the PR url into the ticket's `prs:`.
6. **No review here.** Ping `/notify` if useful, update the ledger, go
   to the next ticket.
7. **Immediately start next** — branch from this PR's tip.

Keep a running ledger (active session doc) of PR / branch / parent /
ticket. Refresh `.claude/bin/status > .status.md` after each slice so a
human checking in overnight sees current progress.

> **Escape hatch:** for trust-critical PRs mid-stack (auth, money,
> migrations) you *may* review immediately. Default is defer-and-batch.

## Context hygiene — `/compact` at checkpoints

Stacked-mr accumulates per-ticket TDD output + diffs + N review verdicts
fast. Ledger + `.status.md` are on disk; the conversation should never be
the source of truth.

Compact at:
1. Every ~3–5 tickets inside Phase 1.
2. The Phase 1 → Phase 2 boundary (build done; diffs no longer needed).
3. After collecting batch verdicts, before handling them (verdicts in
   `.reviews/<pr>/`; keep just per-PR summary + counts).
4. After each fix + re-review.

Prefer out-of-process delegation: each `/code-review` runs in its own
worktree under `codex exec`; verdict comes back, not the transcript.
See `/factory` skill's `[2.6] Orchestrator pattern`.

## Phase 2 — Batch-review the stack

When build phase ends:

1. **Refresh forge state once** so each review resolves the right head
   SHA + base. Build the review list from the ledger.
2. **Fan out one `/code-review` per PR, in parallel, each in its own
   worktree** (concurrent reviews in the same tree corrupt git state):
   ```bash
   wt="${WORKTREES_DIR:-$HOME/.worktrees}/<repo>/<branch>"
   git worktree add "$wt" "<branch>"
   ( cd "$wt" && /code-review for this PR in the background ) &
   ```
   Each is a normal single-PR review — its own base, delta, artifact,
   `findings.json` / `suggestions.json`. "Batch" = orchestration firing
   N at once, not a combined format.
3. **Collect verdicts** into the ledger as they land.
4. **Clean up worktrees** (`git worktree remove "$wt"`) or leave for
   fix-iteration.

See [`.agents/code-review.md`](../../../.agents/code-review.md) →
"Batch stacked-MR review".

## Handling verdicts

- **approve + tests pass + 0 medium+** → that PR hit the bar.
- **request-changes / blocked** → apply fix prompts to **that PR's
  branch** (not the stack tip), push, **re-review just that PR**. Then
  **restack children** — any branches cut from the fixed branch must
  rebase onto its new tip:
  ```bash
  git rebase --onto <fixed-branch> <old-parent-tip> <child-branch>
  git push --force-with-lease origin <child-branch>
  ```
  `--force-with-lease` to a **feature** branch is allowed; never
  main/master. If a bottom-of-stack fix restacks many children,
  re-review the affected sub-chain as a small second batch.

## Stop conditions

- In-scope backlog exhausted.
- True blocker needing a human decision → `/notify --kind=blocked` with
  options; pick a defensible default and continue if possible, else
  pause that line and move to an independent ticket.
- User says stop.
- A PR can't reach passing after reasonable cycles → mark ticket
  `stuck`, note why, move on.

## Morning handoff

Produce a stack summary in dependency order:

```
Stack of N PRs (review bottom-up):
  #1  0012-vault-create   base:main             approve  ✅ tests 9/9
  #2  0013-vault-spend    base:0012-vault-create approve  ✅ tests 12/12
  #3  0014-payment-link   base:0013-vault-spend  request-changes (1 medium) ⚠
```

Include PR url, ticket id, base, latest verdict. Flag `stuck` tickets
and PRs still pending. **After the human merges the batch, run
`/merge-sync`** to close merged tickets and scrub urls.

## Hard rules

1. **Never merge.** No `gh pr merge`, ever (global §8, hook-enforced).
2. **Every PR gets reviewed to the bar** — enforced via end-of-stack
   batch, not per-PR during build. "Stacked" ≠ "unreviewed."
3. **Force-push only to feature branches**, only for restacking, only
   with `--force-with-lease`.
4. **TDD-first** every ticket.
5. **Batch reviews in isolated worktrees**, one per PR.

## Activity

Stacked PRs emit `pr-opened` (via `/pr-creation`) + `pr-verdict` (via
batch `/code-review`). Stack-level:

```bash
.claude/bin/hitl "Stack blocked · <why>" "<action / options>"
.claude/bin/activity task-complete "Stack complete · <N> PRs" "<X approve, Y rc>"
```
