#!/usr/bin/env bash
# bootstrap.sh — inject this workflow into an EXISTING repo.
#
#   ./bootstrap.sh /path/to/target-repo
#
# Copies the workflow machinery (.claude skills/hooks/settings, .agents
# contracts, CI, docs skeleton, backlog/sessions counters, .reviews store) into
# the target. Workflow files are overwritten (they ARE the workflow); your data
# and existing docs are never clobbered. Anything that would clobber an existing
# file is written alongside as `<name>.workflow` for you to merge by hand.
#
# For a brand-new repo, prefer `gh repo create --template <this-template>`
# instead — this script is for retrofitting a repo that already exists.
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
DST="${1:-}"

[ -n "$DST" ] || { echo "usage: $0 /path/to/target-repo" >&2; exit 1; }
[ -d "$DST" ] || { echo "error: target '$DST' is not a directory" >&2; exit 1; }
DST="$(cd "$DST" && pwd)"
[ "$SRC" != "$DST" ] || { echo "error: target is the template itself" >&2; exit 1; }
[ -d "$DST/.git" ] || echo "warning: '$DST' is not a git repo (run 'git init' there)" >&2

say() { printf '  %s\n' "$1"; }

echo "Bootstrapping workflow into: $DST"

# --- workflow machinery (overwrite — this is the workflow) -------------------
echo "[workflow] .claude/ + .agents/ + CI"
mkdir -p "$DST/.claude" "$DST/.agents" "$DST/.github/workflows"
cp -R "$SRC/.claude/skills" "$DST/.claude/"
cp -R "$SRC/.claude/hooks"  "$DST/.claude/"
cp -R "$SRC/.claude/bin"    "$DST/.claude/"
cp "$SRC"/.agents/*.md "$DST/.agents/"
cp "$SRC/.github/workflows/ci.yml" "$DST/.github/workflows/ci.yml"
chmod +x "$DST/.claude/skills/ticket/bin/"* \
         "$DST/.claude/skills/session-start/bin/"* \
         "$DST/.claude/bin/"* \
         "$DST/.claude/hooks/"*.sh 2>/dev/null || true
say ".claude/skills, .claude/hooks, .claude/bin, .agents, .github/workflows/ci.yml installed"

# forge selector — don't clobber an existing choice
[ -f "$DST/.claude/forge" ] || cp "$SRC/.claude/forge" "$DST/.claude/forge"
say "forge selector: $(cat "$DST/.claude/forge") (edit .claude/forge to switch github/gitlab)"

# editor config + PR/MR templates — don't clobber existing project ones
[ -f "$DST/.editorconfig" ] || cp "$SRC/.editorconfig" "$DST/.editorconfig"
mkdir -p "$DST/.github" "$DST/.gitlab/merge_request_templates"
[ -f "$DST/.github/PULL_REQUEST_TEMPLATE.md" ] || \
  cp "$SRC/.github/PULL_REQUEST_TEMPLATE.md" "$DST/.github/PULL_REQUEST_TEMPLATE.md"
[ -f "$DST/.gitlab/merge_request_templates/Default.md" ] || \
  cp "$SRC/.gitlab/merge_request_templates/Default.md" "$DST/.gitlab/merge_request_templates/Default.md"
say ".editorconfig + PR/MR templates seeded (existing left untouched)"

# settings.json — don't clobber an existing one
if [ -f "$DST/.claude/settings.json" ]; then
  cp "$SRC/.claude/settings.json" "$DST/.claude/settings.workflow.json"
  say "settings.json EXISTS → wrote settings.workflow.json (merge the deny list + block-main-merge hook by hand)"
else
  cp "$SRC/.claude/settings.json" "$DST/.claude/settings.json"
  say "settings.json installed"
fi

# --- data scaffolds (seed only if absent — never clobber your data) ----------
echo "[data] backlog/ sessions/ .reviews/ .checks/"
mkdir -p "$DST/backlog" "$DST/sessions" "$DST/.reviews" "$DST/.checks"
[ -f "$DST/backlog/.next-id" ]   || cp "$SRC/backlog/.next-id"   "$DST/backlog/.next-id"
[ -f "$DST/sessions/.next-id" ]  || cp "$SRC/sessions/.next-id"  "$DST/sessions/.next-id"
[ -f "$DST/sessions/README.md" ] || cp "$SRC/sessions/README.md" "$DST/sessions/README.md"
[ -f "$DST/.reviews/README.md" ] || cp "$SRC/.reviews/README.md" "$DST/.reviews/README.md"
[ -f "$DST/.checks/README.md" ]  || cp "$SRC/.checks/README.md"  "$DST/.checks/README.md"
mkdir -p "$DST/.gauntlet-terminal"
[ -f "$DST/.gauntlet-terminal/widgets.json" ] || \
  cp "$SRC/.gauntlet-terminal/widgets.json" "$DST/.gauntlet-terminal/widgets.json"
say "backlog/.next-id, sessions/.next-id, .reviews + .checks READMEs, terminal widgets seeded (existing left untouched)"

# --- docs skeleton (seed only if absent) -------------------------------------
echo "[docs] docs/{decisions,runbooks,learnings} + architecture.md"
mkdir -p "$DST/docs/decisions" "$DST/docs/runbooks" "$DST/docs/learnings"
[ -f "$DST/docs/architecture.md" ] || cp "$SRC/docs/architecture.md" "$DST/docs/architecture.md"
[ -f "$DST/docs/decisions/0001-record-architecture-decisions.md" ] || \
  cp "$SRC/docs/decisions/0001-record-architecture-decisions.md" "$DST/docs/decisions/"
[ -f "$DST/docs/runbooks/README.md" ]  || cp "$SRC/docs/runbooks/README.md"  "$DST/docs/runbooks/README.md"
[ -f "$DST/docs/runbooks/branch-protection.md" ] || \
  cp "$SRC/docs/runbooks/branch-protection.md" "$DST/docs/runbooks/branch-protection.md"
[ -f "$DST/docs/learnings/README.md" ] || cp "$SRC/docs/learnings/README.md" "$DST/docs/learnings/README.md"
say "docs skeleton seeded (existing docs left untouched)"

# --- CLAUDE.md — don't clobber ------------------------------------------------
if [ -f "$DST/CLAUDE.md" ]; then
  cp "$SRC/CLAUDE.md" "$DST/CLAUDE.workflow.md"
  say "CLAUDE.md EXISTS → wrote CLAUDE.workflow.md (merge the 'How we work' + conventions sections by hand)"
else
  cp "$SRC/CLAUDE.md" "$DST/CLAUDE.md"
  say "CLAUDE.md installed (fill in the project-specific placeholders)"
fi

# --- .gitignore — append our entries if missing ------------------------------
echo "[gitignore] appending workflow entries if missing"
touch "$DST/.gitignore"
for line in "backlog/.next-id.lock" "sessions/.next-id.lock" ".status.md"; do
  grep -qxF "$line" "$DST/.gitignore" || printf '%s\n' "$line" >> "$DST/.gitignore"
done
say ".gitignore lock-dir entries ensured"

cat <<EOF

Done. Next steps in $DST:
  1. Fill the placeholders in CLAUDE.md (or merge CLAUDE.workflow.md if present).
  2. Adapt .github/workflows/ci.yml scripts to your project.
  3. If you had a settings.json, merge settings.workflow.json into it.
  4. Commit the scaffold on a feature branch (never main — global §8).
  5. Start working: /session-start "<goal>"  →  /ticket  →  /pr-creation  →  /code-review
EOF
