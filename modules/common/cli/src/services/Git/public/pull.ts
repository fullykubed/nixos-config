import { Effect } from "effect"
import { ShellService } from "../../Shell"
import type { WorktreePath } from "../types"
import { toGitError } from "../errors"

export const pull = (worktreePath: WorktreePath, opts?: { rebase?: boolean }) =>
  Effect.gen(function* () {
    const shell = yield* ShellService
    const args = ["pull"]
    if (opts?.rebase !== false) {
      args.push("--rebase")
    }
    yield* shell.exec("git", args, { cwd: worktreePath }).pipe(
      Effect.catchTag("ShellError", toGitError)
    )
  })
