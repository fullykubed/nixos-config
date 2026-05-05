import { Effect } from "effect"
import { ShellService } from "../../Shell"
import type { WorktreePath } from "../types"
import { toGitError } from "../errors"

export const isDirty = (worktreePath: WorktreePath) =>
  Effect.gen(function* () {
    const shell = yield* ShellService
    const { stdout } = yield* shell.exec("git", ["status", "--porcelain"], { cwd: worktreePath }).pipe(
      Effect.catchTag("ShellError", toGitError)
    )
    return stdout.trim().length > 0
  })
