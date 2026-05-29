#!/usr/bin/env bash
# Example agent script — referenced from .agents/agents.json by id `health`.
# Demonstrates the cheap-precheck-then-LLM pattern described in scripts.md.
#
# Runner env (set by TerMinal before exec):
#   TERMINAL_REPO       repo root
#   TERMINAL_RUN_ID     run uuid
#   TERMINAL_BRANCH     worktree branch (or "main" if inPlace)
#   TERMINAL_WORKTREE   worktree path
#   TERMINAL_ENGINE     hint: claude | codex
#   TERMINAL_MODEL      hint: haiku/sonnet/opus/etc. (optional)
#
# Helpers on PATH (from ~/.config/TerMinal/bin):
#   terminal-cli ticket "<title>" "<body>"
#   terminal-cli hitl "<title>" "<action>"
#   terminal-cli activity <kind> "<title>" "<detail>"
#   terminal-cli notify "<message>"

set -uo pipefail

# -- Cheap precheck. No LLM tokens spent if any of these returns "clean."
precheck_log=$(mktemp)
trap 'rm -f "$precheck_log"' EXIT

probe_ok=true
probes=()

run_probe() {
  local name=$1 ; shift
  if "$@" >>"$precheck_log" 2>&1; then
    probes+=("✔ $name")
  else
    probes+=("✘ $name")
    probe_ok=false
  fi
}

# Add probes that make sense for THIS repo. The example here:
[ -f tsconfig.json ] && run_probe "tsc" bunx tsc --noEmit -p tsconfig.json
[ -f package.json ] && run_probe "tests" bun test --bail
[ -f package.json ] && run_probe "lint" bunx prettier --check .

# Emit a structured activity event regardless so the operator sees the cadence.
summary=$(IFS=' ' ; echo "${probes[*]}")
terminal-cli activity check "Health check" "$summary"

if "$probe_ok"; then
  echo "Healthy — no LLM run needed."
  echo "$summary"
  exit 0
fi

# -- Escalate. Default to a cheap model (haiku) — the escalation explains the
# failures and asks for a small surgical fix.
model=${TERMINAL_MODEL:-haiku}

claude -p "The repo health precheck failed for $TERMINAL_REPO (branch: $TERMINAL_BRANCH).

Probe results:
$summary

Precheck output:
$(cat "$precheck_log")

Diagnose the failures. If you can apply a surgical, scope-respecting fix that
keeps the test suite green, do it: commit on this worktree's branch and open a
PR per the project's pr-creation conventions. If the fix is non-trivial or
risks scope creep, file a backlog ticket via \`terminal-cli ticket\` instead.
If you're blocked entirely (missing credentials, ambiguous requirements), file
a HITL via \`terminal-cli hitl\`." \
  --dangerously-skip-permissions \
  --model "$model"
