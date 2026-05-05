import { Effect, pipe, Option } from "effect"
import type { Parsed } from "./command"
import { TmuxService, NotInsideTmuxError } from "../../../services/Tmux"
import { GitService, GitUnknownError, AbsolutePath, WorktreePath, BranchName } from "../../../services/Git"
import { ShellService } from "../../../services/Shell"
import { MuxService } from "../../../services/Mux"

export const mergeHandler = (parsed: Parsed) =>
  Effect.gen(function* () {
    const tmux = yield* TmuxService
    const git = yield* GitService
    const shell = yield* ShellService
    const _mux = yield* MuxService

    // 1. Verify inside tmux
    const isInsideTmux = yield* tmux.isInsideTmux()
    if (!isInsideTmux) {
      yield* Effect.fail(new NotInsideTmuxError({ message: "Must be inside a tmux session to merge worktrees" }))
    }

    // 2. Verify in a worktree (not main working tree)
    const cwd = AbsolutePath(process.cwd())
    const isWorktreeResult = yield* git.isWorktree(cwd)
    if (Option.isNone(isWorktreeResult)) {
      yield* Effect.fail(new Error("Must be run from inside a worktree (not main working tree)"))
    }
    const worktreePath = Option.getOrThrow(isWorktreeResult)

    // 3. Read project.json config
    const _repoRoot = yield* git.repoRoot(cwd)
    const projectPath = yield* git.projectDir(worktreePath)
    const config = yield* git.getProjectConfig(projectPath)

    // 4. Determine target branch
    const targetBranch = parsed.flags.into ?? (yield* Effect.try({
      try: () => BranchName(config.primary_branch),
      catch: () => new Error(`Invalid branch name in project config: '${config.primary_branch}'`)
    }))

    // 5. Get current branch and worktree info
    const currentBranch = yield* git.currentBranch(worktreePath)
    const gitCommonDir = yield* git.commonDir(worktreePath)
    const worktrees = yield* git.worktreeList(gitCommonDir)
    const primaryWorktree = worktrees.find(w => w.branch === targetBranch)
    if (!primaryWorktree) {
      return yield* Effect.fail(new Error(`Could not find worktree for target branch '${targetBranch}'`))
    }
    const mainPath = primaryWorktree.path

    const currentWorktree = worktrees.find(w => w.branch === currentBranch)
    if (!currentWorktree) {
      return yield* Effect.fail(new Error(`Could not find worktree for current branch '${currentBranch}'`))
    }

    // 6. Run pre_merge hook commands in sequence; abort if any fails
    for (const hookCmd of config.worktree.pre_merge) {
      yield* shell.exec("sh", ["-c", hookCmd], { cwd: worktreePath })
    }

    // 7. Check for uncommitted changes; error if dirty
    const isDirty = yield* git.isDirty(worktreePath)
    if (isDirty) {
      yield* Effect.fail(new Error(`Worktree has uncommitted changes: ${worktreePath}`))
    }

    // 8. Checkout target branch in main worktree
    yield* git.checkout(targetBranch, mainPath)

    // 9. Pull latest
    yield* git.pull(mainPath, { rebase: true })

    // 10. Execute merge strategy
    yield* pipe(
      executeMerge(mainPath, currentBranch, config.worktree.merge_strategy),
      Effect.catchTag("GitUnknownError", (error) =>
        Effect.gen(function* () {
          yield* Effect.logError("Merge conflict detected, aborting merge")
          yield* Effect.logError(`Merge conflict occurred during rebase of '${currentBranch}' onto '${targetBranch}'`)
          yield* Effect.logError("Resolve conflicts manually in the main working tree, then run merge again")
          yield* Effect.logError("Or use `git rebase --abort` in the main tree to cancel")
          yield* Effect.logError(`Details: ${error.message}`)
          return yield* Effect.fail(error)
        })
      )
    )

    // 11. Push
    yield* git.push(mainPath).pipe(
      Effect.catchAll((error) =>
        Effect.gen(function* () {
          yield* Effect.logError(`Failed to push after merge: ${error.message}`)
          return yield* Effect.fail(error)
        })
      )
    )

    // 12. On success: close worktree window, remove worktree, update SQLite
    yield* cleanupWorktree(currentBranch, worktreePath)

    // 13. Print success message with merge summary
    yield* Effect.log(`Successfully merged '${currentBranch}' into '${targetBranch}' using ${config.worktree.merge_strategy} strategy`)
    yield* Effect.log(`Removed worktree and closed tmux window`)
  })

const executeMerge = (
  mainPath: WorktreePath,
  worktreeBranch: BranchName,
  strategy: "rebase" | "squash" | "merge",
) =>
  Effect.gen(function* () {
    const git = yield* GitService
    const shell = yield* ShellService

    switch (strategy) {
      case "rebase":
        yield* git.rebase(worktreeBranch, mainPath).pipe(
          Effect.catchTag("GitUnknownError", (e) =>
            Effect.gen(function* () {
              // Abort the failed rebase
              yield* shell.exec("git", ["-C", mainPath, "rebase", "--abort"]).pipe(Effect.ignore)
              return yield* Effect.fail(new GitUnknownError({
                message: e.message,
              }))
            })
          )
        )
        break
      case "squash":
        yield* git.mergeSquash(worktreeBranch, mainPath)
        yield* git.commit(mainPath)
        break
      case "merge":
        yield* git.merge(worktreeBranch, mainPath)
        break
    }
  })

const cleanupWorktree = (
  branch: BranchName,
  worktreePath: WorktreePath,
) =>
  Effect.gen(function* () {
    const git = yield* GitService
    const mux = yield* MuxService

    const projectPath = yield* git.projectDir(worktreePath)
    const entry = yield* mux.getWorktreeFromBranch(projectPath, branch)
    if (Option.isSome(entry)) {
      yield* mux.removeWorktree(entry.value.id)
    }
  }).pipe(Effect.catchAll(() => Effect.void)) // Ignore cleanup failures - best effort
