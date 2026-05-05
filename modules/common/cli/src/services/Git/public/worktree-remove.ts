import { Effect } from "effect"
import { ShellService } from "../../Shell"
import type { WorktreePath } from "../types"
import { toGitError } from "../errors"

export const worktreeRemove = (worktreePath: WorktreePath, opts?: { force?: boolean }) =>
  Effect.gen(function* () {
    const shell = yield* ShellService
    const args = ["worktree", "remove", worktreePath]
    if (opts?.force) {
      args.push("--force")
    }
    yield* shell.exec("git", args, { cwd: worktreePath }).pipe(
      Effect.catchTag("ShellError", toGitError)
    )
  })
