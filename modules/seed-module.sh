#!/usr/bin/env bash
# seed-module.sh <repo> <module-id>
#
# Copies modules/<id>/seed/. into <repo> with the same discipline as bootstrap.sh:
#   - workflow-owned files are overwritten (that's the point of the template);
#   - anything in the module's `preserve` list is NEVER clobbered — a `<file>.seed`
#     sidecar is written next to the user's file for manual merge;
#   - .gitignore lines in the module's `gitignore` list are appended if missing.
# Idempotent and re-runnable. The single copy engine shared by the TerMinal IPC
# (modules:seed) and the CLI (terminal-cli seed-module) so semantics can't diverge.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"   # .../modules
REG="$HERE/modules.json"
DST="${1:?usage: seed-module.sh <repo> <module-id>}"
ID="${2:?usage: seed-module.sh <repo> <module-id>}"
SEED="$HERE/$ID/seed"

[ -d "$SEED" ] || { echo "seed-module: no seed dir for '$ID' at $SEED" >&2; exit 1; }
[ -d "$DST" ]  || { echo "seed-module: repo '$DST' not found" >&2; exit 1; }

# Read preserve[]/gitignore[] for this module from modules.json via bun (the stack
# runtime). Falls back to empty if bun/parse unavailable — then everything copies.
read_arr() {
  bun -e '
    const fs=require("fs");
    const reg=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
    const m=(reg.modules||[]).find(x=>x.id===process.argv[2])||{};
    const a=(process.argv[3]==="preserve"?m.seed&&m.seed.preserve:m.seed&&m.seed.gitignore)||[];
    process.stdout.write(a.join("\n"));
  ' "$REG" "$ID" "$1" 2>/dev/null || true
}
PRESERVE="$(read_arr preserve)"
GITIGNORE="$(read_arr gitignore)"

is_preserved() {
  local rel="$1"; [ -n "$PRESERVE" ] || return 1
  while IFS= read -r p; do [ -n "$p" ] && [ "$p" = "$rel" ] && return 0; done <<< "$PRESERVE"
  return 1
}

# Walk the seed tree and place each file.
( cd "$SEED" && find . -type f | sed 's|^\./||' ) | while IFS= read -r rel; do
  [ -z "$rel" ] && continue
  dstfile="$DST/$rel"
  mkdir -p "$(dirname "$dstfile")"
  existed=false; [ -e "$dstfile" ] && existed=true
  if $existed && is_preserved "$rel"; then
    cp "$SEED/$rel" "$dstfile.seed"
    echo "[seed:$ID] EXISTS $rel → wrote $rel.seed (merge by hand)"
  else
    cp "$SEED/$rel" "$dstfile"
    $existed && echo "[seed:$ID] updated $rel" || echo "[seed:$ID] added $rel"
  fi
done

# Ensure .gitignore entries.
if [ -n "$GITIGNORE" ]; then
  touch "$DST/.gitignore"
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    grep -qxF "$line" "$DST/.gitignore" || printf '%s\n' "$line" >> "$DST/.gitignore"
  done <<< "$GITIGNORE"
fi

echo "[seed:$ID] done"
