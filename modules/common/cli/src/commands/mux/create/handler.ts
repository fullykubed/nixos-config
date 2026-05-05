import { Effect } from "effect"
import { GitService, AbsolutePath } from "../../../services/Git"
import { MuxService } from "../../../services/Mux"
import type { Parsed } from "./command"

export const createHandler = (parsed: Parsed) =>
  Effect.gen(function* () {
    const git = yield* GitService
    const mux = yield* MuxService

    const branch = parsed.args.branch
    const worktreeRoot = yield* git.repoRoot(AbsolutePath(process.cwd()))
    const projectPath = yield* git.projectDir(worktreeRoot)

    yield* mux.createWorktree(projectPath, branch).pipe(
      Effect.catchTag("MuxBranchExistsOnRemoteError", (e) =>
        Effect.fail(new Error(`Branch '${e.branch}' already exists on origin.`, { cause: e }))
      ),
      Effect.catchTag("MuxBranchExistsLocallyError", (e) => {
        const msg = e.hasWorktree
          ? `Branch '${e.branch}' already has a worktree.`
          : `Branch '${e.branch}' already exists.`
        return Effect.fail(new Error(msg, { cause: e }))
      }),
      Effect.catchTag("MuxWorktreePathConflictError", (e) =>
        Effect.fail(new Error(`Path '${e.path}' already exists. Remove it or choose a different branch name.`, { cause: e }))
      ),
      Effect.catchTag("MuxCreateWorktreeError", (e) =>
        Effect.fail(new Error(`Failed to set up worktree for branch '${e.branch}': ${e.cause instanceof Error ? e.cause.message : String(e.cause)}`, { cause: e }))
      ),
    )

    yield* Effect.log(`Created worktree and tmux window for branch: ${branch}`)
  })
