---
name: new-snippet
description: "Create or update a TerMinal quick snippet. Use when the user runs /new-snippet, asks for a reusable quick prompt, or wants a one-click terminal launcher item. Writes .TerMinal/snippets.json for repo snippets or ~/.config/TerMinal/snippets.json for global snippets."
---

# /new-snippet — Create a TerMinal Quick Snippet

Create one reusable prompt snippet for TerMinal's terminal quick launcher.

## Target Files

Default target is the current repo:

- `.TerMinal/snippets.json`

If the user explicitly asks for a global snippet, write:

- `~/.config/TerMinal/snippets.json`

Treat a missing file as:

```json
{ "version": 1, "snippets": [] }
```

## Schema

```json
{
  "version": 1,
  "snippets": [
    {
      "id": "kebab-case",
      "title": "Short label",
      "group": "Common",
      "description": "Optional one-line description",
      "prompt": "Prompt text inserted into the active terminal"
    }
  ]
}
```

## Workflow

1. Read existing snippets from the target file.
2. Pick a short kebab-case `id`, a clear `title`, and a useful `group`.
3. Write one focused `prompt` that is safe to paste into Claude Code or Codex.
4. Append or replace the snippet with the same `id`.
5. Preserve existing snippets and write JSON with 2-space indentation.

## Rules

- Do not create broad, multi-purpose snippets.
- Do not include secrets or machine-specific paths unless the user explicitly asks.
- Keep prompt text direct and action-oriented.
- Prefer groups like `Common`, `Checks`, `Review`, `Git`, `Tickets`, `Docs`, `Debug`, `Refactor`, `Tests`, or `Context`.

End with the path updated and the snippet title.
