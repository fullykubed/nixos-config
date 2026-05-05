import { Effect } from "effect"
import { ShellService } from "../../Shell"
import type { WorktreePath } from "../types"
import { toGitError } from "../errors"

export const push = (worktreePath: WorktreePath) =>
  Effect.gen(function* () {
    const shell = yield* ShellService
    yield* shell.exec("git", ["push"], { cwd: worktreePath }).pipe(
      Effect.catchTag("ShellError", toGitError)
    )
  })
