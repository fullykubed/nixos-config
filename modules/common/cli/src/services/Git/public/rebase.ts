import { Effect } from "effect"
import { ShellService } from "../../Shell"
import type { BranchName, WorktreePath } from "../types"
import { toGitError } from "../errors"

export const rebase = (onto: BranchName, worktreePath: WorktreePath) =>
  Effect.gen(function* () {
    const shell = yield* ShellService
    yield* shell.exec("git", ["rebase", onto], { cwd: worktreePath }).pipe(
      Effect.catchTag("ShellError", toGitError)
    )
  })
