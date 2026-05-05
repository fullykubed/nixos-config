import { Brand } from "effect"
import type { ProjectId, ProjectPath, BranchName, WorktreePath } from "../Git"

export interface MuxWorktree {
  readonly id: WorktreeId
  readonly project_id: ProjectId
  readonly project_path: ProjectPath
  readonly path: WorktreePath
  readonly branch: BranchName
  readonly created_at: string
}

/** Tmux user option key used to tag sessions with their mux project id. */
export const MUX_PROJECT_ID_OPTION = "@mux_project_id"

/** Tmux user option key used to tag windows with their mux worktree id. */
export const MUX_WORKTREE_ID_OPTION = "@mux_worktree_id"

/** UUID worktree identifier. */
export type WorktreeId = string & Brand.Brand<"WorktreeId">

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

export const WorktreeId = Brand.refined<WorktreeId>(
  (s): s is WorktreeId => UUID_RE.test(s),
  () => Brand.error("a valid UUID")
)
