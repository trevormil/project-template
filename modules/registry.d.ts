// Capability module registry — canonical types.
// project-template owns this file; TerMinal mirrors the shape in src/main/modules.ts.
// Registry DATA lives in modules.json (read at runtime), so TerMinal ships types only.

export type ModuleId =
  | 'health'
  | 'feedback'
  | 'api-docs'
  | 'deploy'
  | 'observability'
  | 'testing'

export type ProfileId = 'web-service' | 'library' | 'cli' | 'worker'
export type ModuleScope = 'repo' | 'platform'

// FACE 3 data adapters — "fetch it however"; the Admin panel renders widgets from these.
export type DataSource =
  | { kind: 'file'; path: string } // local JSONL/logs (repo-relative)
  | { kind: 'cli'; cmd: string } // shell-out, e.g. `kubectl get pods -o json`
  | { kind: 'http'; url: string } // /metrics, /health, /v1/schema
  | { kind: 'db'; conn: string; query: string } // remote Postgres/etc (conn key resolved from admin.local.json)

export type WidgetSpec = {
  kind: 'status' | 'table' | 'chart' | 'sparkline' | 'logtail' | 'stat'
  source: number // index into surface.data
  title: string
  map?: Record<string, string>
}

export type ModuleLink = { label: string; url: string }
export type ModuleAction = {
  id: string
  label: string
  kind: 'seed' | 'apply-profile' | 'toggle-schedule' | 'run-check' | 'cli'
  cmd?: string // for kind:'cli'
  agentId?: string // for kind:'toggle-schedule' | 'run-check'
}

export type SeededScheduleSpec = {
  agentId: string
  spec: { everyMinutes?: number; minute?: number; hour?: number; weekdays?: number[] }
  engine?: 'claude' | 'codex'
  model?: string
}

export type CapabilityModule = {
  id: ModuleId
  title: string
  summary: string
  scope: ModuleScope
  // FACE 1 — what lands in the repo (dir modules/<id>/seed copied to repo root)
  seed: { root: 'seed'; preserve?: string[]; gitignore?: string[] }
  // FACE 2 — per-repo presence probing (fallback; template.json modules{} is authoritative)
  detect: { markers: string[]; requireAll?: string[] }
  // FACE 3 — Admin surface
  surface: {
    adminLabel: string
    group: string
    docPath?: string
    data?: DataSource[]
    widgets?: WidgetSpec[]
    links?: ModuleLink[]
    actions?: ModuleAction[]
  }
  // FACE 4 — full-auto factory wiring (schedules seeded disabled)
  automate: { agents?: string[]; schedules?: SeededScheduleSpec[]; filesTickets?: boolean }
}

export type ModuleRegistry = {
  version: 1
  modules: CapabilityModule[]
  profiles: Record<ProfileId, ModuleId[]>
}
