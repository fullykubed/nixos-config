import { Effect } from "effect"
import { ShellService } from "../../Shell"
import type { GitCommonPath } from "../types"
import { toGitError } from "../errors"

export const fetch = (remote: string, gitCommonDir: GitCommonPath) =>
  Effect.gen(function* () {
    const shell = yield* ShellService
    yield* shell.exec("git", ["fetch", remote], { cwd: gitCommonDir }).pipe(
      Effect.catchTag("ShellError", toGitError)
    )
  })
