import { Effect, Option } from "effect"
import { GitService, type AbsolutePath } from "../../Git"
import { getWorktreeFromBranch } from "./get-worktree-from-branch"

export const getWorktreeFromPath = (path: AbsolutePath) =>
  Effect.gen(function* () {
    const git = yield* GitService

    const repoRoot = yield* git.repoRoot(path)
    const gitCommonDir = yield* git.commonDir(repoRoot)
    const projectPath = yield* git.projectDir(repoRoot)
    const worktrees = yield* git.worktreeList(gitCommonDir)
    const worktree = worktrees.find(w => w.path === repoRoot)

    if (!worktree?.branch) {
      return Option.none()
    }

    return yield* getWorktreeFromBranch(projectPath, worktree.branch)
  })
