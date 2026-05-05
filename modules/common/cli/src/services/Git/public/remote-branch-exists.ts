import { Effect, Either } from "effect"
import { ShellService } from "../../Shell"
import { fetch } from "./fetch"
import { hasRemote } from "./has-remote"
import type { BranchName, GitCommonPath } from "../types"
import { classifyGitError } from "../errors"

export const remoteBranchExists = (remote: string, branch: BranchName, gitCommonDir: GitCommonPath) =>
  Effect.gen(function* () {
    const shell = yield* ShellService

    const remoteConfigured = yield* hasRemote(remote, gitCommonDir)
    if (!remoteConfigured) return false
    yield* fetch(remote, gitCommonDir)

    const ref = `refs/remotes/${remote}/${branch}`
    const result = yield* shell.exec("git", ["rev-parse", "--verify", "--quiet", ref], { cwd: gitCommonDir }).pipe(
      Effect.either
    )

    if (Either.isLeft(result)) {
      const e = result.left
      if (e.exitCode === 1 || e.exitCode === 128) {
        return false
      }
      return yield* Effect.fail(classifyGitError(e))
    }

    return true
  })
