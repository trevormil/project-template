You are producing a **human-review digest patch** for MR !{{PR}} at {{SHORT}}.
Follow `.agents/digest.md` exactly. This is NOT a code review — do not score, do
not decide merge-readiness. Your only job: help a technical developer read this
diff fast, without hiding any code.

## Inputs (already on disk — read them, don't recompute)

- Chunk skeleton: `{{DIR}}/{{SHORT}}.chunks.json`
  Every changed file is already classified into a chunk with `id`, `file`,
  `kind`, `risk`, and `decision_signals`. 🟢 chunks are DONE — ignore them.
- Full diff: `{{DIFF_PATH}}` (`git diff origin/{{BASE}}...{{HEAD}}`).

## Output (write this file and nothing else)

Write `{{DIR}}/{{SHORT}}.digest-patch.json` — a single JSON object:

```json
{
  "brief": "3–5 sentences: what this MR does, why, blast radius. Prose, plain.",
  "blast_radius": "one line: subsystems touched + worst-case if wrong",
  "diagram": null,
  "double_check": [{ "file": "path:line", "why": "one line" }],
  "decisions": [],
  "chunks": {}
}
```

## Rules (token discipline is the point)

1. **Only annotate non-🟢 chunks.** For each chunk in the skeleton whose `risk`
   is `yellow` or `red`, add an entry under `chunks` keyed by its `id`:
   - `summary`: ≤ 200 chars, what THIS file's change does. No restating the diff
     line by line.
   - `note`: exactly one of `rubber-stamp` / `eyeball <what>` / `verify: <how>`.
   - `risk`: include ONLY to override — raise 🟡→🔴 with reason in the note, or
     lower a trivial 🟡 test/config to 🟢. You may never lower a 🔴. Omit
     otherwise.
   - `confidence`: include ONLY when you are genuinely unsure
     (`"low: <why>"`). Omit when confident — silence is the signal.
   Do NOT write entries for 🟢 chunks. Do NOT echo the diff.

2. **Architecture & design decisions (first-class).** Read every chunk whose
   `decision_signals` is non-empty. Synthesize the actual decisions into
   `decisions[]`: merge signals that belong to one decision (e.g. a new type +
   its route + its dependency = one decision), write `what` / `why` (from the
   diff/comments, else null) / `alternatives` (or null) / `reversibility`
   (`low`/`medium`/`high`). Prune false positives. Add any real decision the
   heuristics missed. `low` reversibility = migrations, public API, service
   lock-in.

3. **`diagram`** — set to a mermaid string ONLY if the change alters structure
   (adds/removes files, exports, routes, cross-module edges). Otherwise `null`.
   `graph LR` for "how it fits", `sequenceDiagram` for a changed flow.

4. **`double_check`** — the 1–3 specific spots a human should personally eyeball,
   by `file:line`. Empty array if it's all rubber-stamp.

5. **No prose anywhere but `brief`.** No markdown, no commentary, no review
   verdict. Just the JSON object, written to the path above.

When done, confirm only: the patch path + counts (chunks annotated, decisions).
