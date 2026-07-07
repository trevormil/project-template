# API docs module

Self-hosted, zero-service OpenAPI docs (the bestie-api standard, library-ized).

- `docs/api/contract.config.ts` — list the zod schemas to export (PRESERVE: yours).
- `scripts/export-api-contract.ts` — zod → `docs/api/openapi.json` (single source of truth), also served at `/v1/schema`.
- `docs/api/template.html` → rendered to `docs/api/index.html`, self-contained, served at `/docs`.

Regen: `bun scripts/export-api-contract.ts`. The `api-docs-drift` agent files a ticket
when a served endpoint is undocumented or the schema stops validating.

> Phase-0 stub — the template.html + export script land in Phase 1.
