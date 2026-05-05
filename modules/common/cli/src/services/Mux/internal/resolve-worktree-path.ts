import { Effect } from "effect"
import { GitService, type ProjectPath, type BranchName } from "../../Git"
import { MuxStoreError } from "../errors"

/**
 * Resolve the filesystem path of a worktree by looking it up in `git worktree list`.
 * Fails with MuxStoreError if the worktree is not found on disk.
 */
export const resolveWorktreePath = (projectPath: ProjectPath, branch: BranchName) =>
  Effect.gen(function* () {
    const git = yield* GitService
    const commonDir = yield* git.commonDir(projectPath)
    const worktrees = yield* git.worktreeList(commonDir)
    const match = worktrees.find(w => w.branch === branch)
    if (!match) {
      return yield* new MuxStoreError({
        operation: "resolveWorktreePath",
        message: `Worktree not found on disk for branch '${branch}' in ${projectPath}`,
        project_path: projectPath,
        branch,
      })
    }
    return match.path
  })
