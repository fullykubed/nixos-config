import { Effect } from "effect"
import { ShellService } from "../../Shell"
import type { BranchName, WorktreePath } from "../types"
import { toGitError } from "../errors"

export const checkout = (branch: BranchName, worktreePath: WorktreePath) =>
  Effect.gen(function* () {
    const shell = yield* ShellService
    yield* shell.exec("git", ["checkout", branch], { cwd: worktreePath }).pipe(
      Effect.catchTag("ShellError", toGitError)
    )
  })
