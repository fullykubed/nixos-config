import { Effect } from "effect"
import { StoreService } from "../../Store"
import type { ProjectId, BranchName } from "../../Git"
import type { WorktreeId } from "../types"
import { MuxStoreError } from "../errors"

/**
 * Record a new worktree entry in the DB with the given id.
 */
export const trackWorktree = (
  projectId: ProjectId,
  branch: BranchName,
  worktreeId: WorktreeId,
) =>
  Effect.gen(function* () {
    const db = yield* StoreService
    yield* Effect.tryPromise({
      try: () => db.insertInto("mux_worktrees")
        .values({ id: worktreeId, project_id: projectId, branch })
        .execute(),
      catch: (e) => new MuxStoreError({
        operation: "trackWorktree",
        message: e instanceof Error ? e.message : String(e),
        branch,
      }),
    })
  })
