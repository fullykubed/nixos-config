import type { Generated } from "kysely"

interface LocksTable {
  name: string
  pid: number
  acquired_at: Generated<string>
}

export interface MuxProjectsTable {
  id: string
  path: string
}

export interface MuxWorktreesTable {
  id: string
  project_id: string
  branch: string
  created_at: Generated<string>
  deleted_at: string | null
}

export interface DB {
  locks: LocksTable
  mux_projects: MuxProjectsTable
  mux_worktrees: MuxWorktreesTable
}
