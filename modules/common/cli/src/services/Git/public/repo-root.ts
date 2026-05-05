import { Effect } from "effect"
import { ShellService } from "../../Shell"
import type { AbsolutePath } from "../types"
import { WorktreePath } from "../types"
import { toGitError } from "../errors"

export const repoRoot = (path: AbsolutePath) =>
  Effect.gen(function* () {
    const shell = yield* ShellService
    const { stdout } = yield* shell.exec("git", ["rev-parse", "--show-toplevel"], { cwd: path }).pipe(
      Effect.catchTag("ShellError", toGitError)
    )
    return WorktreePath(stdout.trim())
  })
