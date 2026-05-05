import type { Generated } from "kysely"
import type { ProjectId, ProjectPath, BranchName } from "../Git"
import type { WorktreeId } from "../Mux/types"

interface LocksTable {
  name: string
  pid: number
  acquired_at: Generated<string>
}

export interface MuxProjectsTable {
  id: ProjectId
  path: ProjectPath
}

export interface MuxWorktreesTable {
  id: WorktreeId
  project_id: ProjectId
  branch: BranchName
  created_at: Generated<string>
  deleted_at: string | null
}

export interface DB {
  locks: LocksTable
  mux_projects: MuxProjectsTable
  mux_worktrees: MuxWorktreesTable
}
