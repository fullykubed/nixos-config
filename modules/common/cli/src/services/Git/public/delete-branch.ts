import { Effect } from "effect"
import { ShellService } from "../../Shell"
import type { BranchName, GitCommonPath } from "../types"
import { toGitError } from "../errors"

export const deleteBranch = (
  branch: BranchName,
  gitCommonDir: GitCommonPath,
  opts?: { force?: boolean },
) =>
  Effect.gen(function* () {
    const shell = yield* ShellService
    const flag = opts?.force ? "-D" : "-d"
    yield* shell
      .exec("git", ["branch", flag, branch], { cwd: gitCommonDir })
      .pipe(Effect.catchTag("ShellError", toGitError))
  })
