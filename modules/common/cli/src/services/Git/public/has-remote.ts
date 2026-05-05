import { Effect } from "effect"
import { ShellService } from "../../Shell"
import type { GitCommonPath } from "../types"
import { classifyGitError } from "../errors"

export const hasRemote = (remote: string, gitCommonDir: GitCommonPath) =>
  Effect.gen(function* () {
    const shell = yield* ShellService
    const result = yield* shell.exec("git", ["remote", "get-url", remote], { cwd: gitCommonDir }).pipe(
      Effect.catchTag("ShellError", (e) => {
        const classified = classifyGitError(e)
        if (classified._tag === "GitRemoteDoesNotExistError") {
          return Effect.succeed({ stdout: "", stderr: e.stderr, exitCode: e.exitCode })
        }
        return Effect.fail(classified)
      })
    )
    return result.stdout.trim().length > 0
  })
