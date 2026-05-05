import { Effect } from "effect"
import { ShellService } from "../../Shell"
import type { WorktreePath } from "../types"
import { toGitError } from "../errors"

export const commit = (worktreePath: WorktreePath, message?: string) =>
  Effect.gen(function* () {
    const shell = yield* ShellService
    const args = message ? ["commit", "-m", message] : ["commit", "--no-edit"]
    yield* shell.exec("git", args, { cwd: worktreePath }).pipe(
      Effect.catchTag("ShellError", toGitError)
    )
  })
