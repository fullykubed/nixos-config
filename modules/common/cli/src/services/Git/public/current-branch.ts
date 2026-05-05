import { Effect } from "effect"
import { ShellService } from "../../Shell"
import type { WorktreePath } from "../types"
import { BranchName } from "../types"
import { toGitError } from "../errors"

export const currentBranch = (cwd: WorktreePath) =>
  Effect.gen(function* () {
    const shell = yield* ShellService
    const { stdout } = yield* shell.exec("git", ["rev-parse", "--abbrev-ref", "HEAD"], { cwd }).pipe(
      Effect.catchTag("ShellError", toGitError)
    )
    return BranchName(stdout.trim())
  })
