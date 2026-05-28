---
name: stacked-mr
description: "Autonomous AFK mode that works a queue of tickets as a STACK of PRs: each branch is cut from the prior PR's tip (base = parent branch), implemented TDD-first, pushed, opened as a PR, and code-reviewed to passing — then immediately start the next PR on top WITHOUT waiting for a merge. No human in the loop until morning, when the user reviews the whole stack. Use when the user runs /stacked-mr or asks to stack PRs overnight / autonomously."
---

# /stacked-mr — Autonomous overnight PR stacking

A long-running, AFK, no-human-in-the-loop mode. Instead of one ticket → one PR →
wait for merge, this **stacks**: branch N+1 is cut from branch N's tip, so work
keeps flowing without ever merging to `main`. The human reviews the entire stack
(often ~20 PRs) in the morning and merges bottom-up themselves (global §8 — merge
is still human-only).

Each PR in the stack is still **fully code-reviewed to a passing bar** along the
way — this is not "skip review", it's "don't wait for a human merge between PRs".

> Forge-agnostic: this doc says "PR" / `gh`, but the stacking model is identical
> on GitLab — "MR" / `glab mr create --target-branch <parent>` (resolve with
> `.claude/bin/forge`; mapping in [`.agents/forge.md`](../../../.agents/forge.md)).

## Invocation

```
/stacked-mr "work the vault + payment tickets"      # scoped to a goal
/stacked-mr                                          # work the now/next backlog in priority order
```

This is an AFK mode: **arm the Telegram bridge** (`/notify`) at kickoff and ping
at checkpoints. If the machine has no Telegram setup, run anyway but say so.

## The stacking model

```
main
 └─ 0012-vault-create        (PR #1, base: main)
     └─ 0013-vault-spend     (PR #2, base: 0012-vault-create)
         └─ 0014-payment-link (PR #3, base: 0013-vault-spend)
             └─ ...
```

- Each branch is created from the **previous branch's tip**, not `main`.
- Each PR's **base** is its parent branch, so the PR diff (and the review) is
  just that PR's own delta — clean, reviewable units.
- `gh pr create --base <parent-branch>` sets this. `/code-review` resolves the
  base from the PR, so it reviews the right delta automatically.

## Loop (per ticket)

1. **Pick the next ticket** — from the goal, else the backlog by horizon
   (`now`, then `next`) and priority. Skip `future` unless told. Set the ticket
   `status: in-progress`.
2. **Cut the stacked branch** from the current stack tip:
   ```bash
   parent="<previous branch, or origin/main for the first>"
   branch="<id>-<slug>"
   git switch -c "$branch" "$parent"
   ```
3. **Implement TDD-first** — write the failing test, then the code to pass it.
   Commit incrementally. (See the project's TDD gate in CLAUDE.md.)
4. **Sanity-check + push** — type-check/build, eyeball the diff, then
   `git push -u origin "$branch"`.
5. **Open the PR** with `--base "$parent"`:
   ```bash
   gh pr create --base "$parent" --title "<ticket title>" --body "<summary + stack position + test plan>"
   ```
   Note the stack position in the body ("Stacked on #<parent-PR>. Part N of the
   <goal> stack."). Link the PR url into the ticket's `prs:`.
6. **Fire `/code-review` in the background** (it's the dev-speed bottleneck;
   ~4 min) — do NOT wait. Ping a checkpoint via `/notify`.
7. **Immediately start the next ticket on top** (step 1), branching from this
   PR's tip — the *unreviewed* tip. This is the non-blocking pipeline: keep
   stacking while reviews run in the background.

## Handling review verdicts as they land

Reviews complete asynchronously. When a `/code-review` notification arrives:

- **approve + tests pass + 0 medium+ findings** → that PR has hit the bar. Note
  it in the morning summary; nothing else to do.
- **request-changes / blocked** → apply the findings' fix prompts to **that PR's
  branch** (not the tip of the stack), push the fix, and re-fire `/code-review`
  (background) for that PR. Then **restack children**: any branches cut from the
  fixed branch must be rebased onto its new tip so the stack stays coherent:
  ```bash
  git rebase --onto <fixed-branch> <old-parent-tip> <child-branch>
  git push --force-with-lease origin <child-branch>
  ```
  (`--force-with-lease` to a **feature** branch is allowed by the merge hook;
  never to main/master.)

Keep a running ledger (in the active session doc, or a scratch note) of every
PR, its branch, its parent, and its latest review verdict. **Refresh
`.claude/bin/status > .status.md` after each slice** so a human checking in
overnight sees current progress + anything that started needing them, without
reading the transcript.

## Stop conditions

- Backlog queue (in-scope horizon) exhausted.
- A **true blocker** needing a human decision (ambiguous spec, a destructive or
  cost-bearing action, a design fork) → `/notify --kind=blocked` with options,
  pick a defensible default and continue if possible, else pause that line and
  move to an independent ticket.
- The user says stop / "I'm back".
- A PR can't reach passing after a reasonable number of fix cycles → mark the
  ticket `stuck`, note why, and move on (don't burn the night on one PR).

## Morning handoff

When the run ends (or the user returns), produce a **stack summary** in
dependency order:

```
Stack of N PRs (review bottom-up; merge after review):
  #1  0012-vault-create   base:main             approve   ✅ tests 9/9
  #2  0013-vault-spend     base:0012-vault-create approve   ✅ tests 12/12
  #3  0014-payment-link    base:0013-vault-spend  request-changes (1 medium) ⚠ — fix pushed, re-review running
  ...
```

Include each PR url, ticket id, base branch, and latest verdict. Flag any
`stuck` tickets and any PRs still awaiting a verdict. The human merges
bottom-up; as each merges, the next PR's base auto-retargets on GitHub (or note
where a restack is needed). **After the human finishes merging the batch, run
`/merge-sync`** to close the merged tickets and scrub their PR urls from `prs:`.

## Hard rules

1. **Never merge.** No `gh pr merge`, ever (global §8, hook-enforced). The stack
   waits for the human.
2. **Every PR gets reviewed to the bar.** approve + tests pass + 0 medium+
   findings. "Stacked" is not "unreviewed".
3. **Force-push only to feature branches**, only for restacking, only with
   `--force-with-lease`. Never to main/master.
4. **TDD-first** on every ticket — failing test before code.
5. **Reviews run in the background**; keep stacking while they run. Don't block
   the pipeline on a verdict.
6. **One stack tip at a time.** The "current tip" is well-defined; always branch
   the next PR from it (or from a deliberate earlier point for parallel lines —
   note it in the ledger if so).

## What this is NOT

- Not a merge bot. It opens and reviews PRs; humans merge.
- Not a review skipper. The passing bar holds for every PR.
- Not for trust-critical one-offs that need human eyes mid-flight — use
  `/pr-creation` + manual `/code-review` for those.
