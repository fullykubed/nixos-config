import { Effect, Option } from "effect"
import type { Parsed } from "./command"
import { TmuxService, NotInsideTmuxError } from "../../../services/Tmux"
import { GitService, AbsolutePath, BranchName } from "../../../services/Git"
import { MuxService, WorktreeId } from "../../../services/Mux"

export const removeHandler = (parsed: Parsed) =>
  Effect.gen(function* () {
    const tmux = yield* TmuxService
    const git = yield* GitService
    const mux = yield* MuxService

    // 1. Verify inside tmux
    const isInsideTmux = yield* tmux.isInsideTmux()
    if (!isInsideTmux) {
      yield* Effect.fail(new NotInsideTmuxError({ message: "Must be inside a tmux session to remove worktrees" }))
    }

    // 2. Determine target branch
    const providedBranch = parsed.args.branch
    const cwd = AbsolutePath(process.cwd())
    const isWorktreeResult = yield* git.isWorktree(cwd)

    const targetBranch: BranchName = yield* Effect.gen(function* () {
      if (providedBranch) {
        return providedBranch
      } else if (Option.isSome(isWorktreeResult)) {
        return yield* git.currentBranch(isWorktreeResult.value)
      } else {
        // 3. Error if on main working tree and no branch specified
        return yield* Effect.fail(new Error("Specify a branch name or run from inside a worktree"))
      }
    })

    // Get repo root and worktree path
    const repoRoot = yield* git.repoRoot(cwd)
    const gitCommonDir = yield* git.commonDir(repoRoot)
    const worktrees = yield* git.worktreeList(gitCommonDir)
    const worktree = worktrees.find(w => w.branch === targetBranch)

    if (!worktree) {
      return yield* Effect.fail(new Error(`Worktree for branch '${targetBranch}' not found`))
    }

    const worktreePath = worktree.path

    // 4. Check if worktree has uncommitted changes
    const isDirty = yield* git.isDirty(worktreePath)
    const forceFlag = parsed.flags.force

    if (isDirty && !forceFlag) {
      // 5. Prompt for confirmation if dirty and no --force
      const isInteractive = yield* Effect.try({
        try: () => process.stdin.isTTY,
        catch: () => false
      })

      if (isInteractive) {
        // Interactive prompt
        const confirmed = yield* Effect.tryPromise({
          try: async () => {
            process.stdout.write("Worktree has uncommitted changes. Remove? [y/N] ")

            return new Promise<boolean>((resolve) => {
              process.stdin.resume()
              process.stdin.setEncoding('utf8')
              process.stdin.once('data', (chunk: string) => {
                process.stdin.pause()
                const response = chunk.trim().toLowerCase()
                resolve(response === 'y' || response === 'yes')
              })
            })
          },
          catch: (e) => new Error(`Failed to read confirmation: ${e instanceof Error ? e.message : String(e)}`)
        })

        if (!confirmed) {
          yield* Effect.log("Removal cancelled.")
          return
        }
      } else {
        // Non-interactive, require --force
        yield* Effect.fail(new Error(`Worktree has uncommitted changes. Use --force to remove anyway: ${worktreePath}`))
      }
    }

    // 6. Remove worktree (git + tmux + DB handled by service)
    const entry = yield* mux.find(gitCommonDir, targetBranch)
    const windowClosed = entry
      ? (yield* mux.removeWorktree(WorktreeId(entry.id))).windowClosed
      : false

    // 7. Print success message
    yield* Effect.log(`Removed worktree '${targetBranch}'${windowClosed ? " and closed tmux window" : ""}`)
  })
