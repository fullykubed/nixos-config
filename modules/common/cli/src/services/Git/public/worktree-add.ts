import { Effect } from "effect"
import { Path } from "@effect/platform"
import { ShellService } from "../../Shell"
import type { BranchName, GitCommonPath } from "../types"
import { WorktreePath } from "../types"
import { toGitError } from "../errors"

export const worktreeAdd = (
  branch: BranchName,
  gitCommonDir: GitCommonPath,
  opts?: { path?: string; create?: boolean },
) =>
  Effect.gen(function* () {
    const shell = yield* ShellService
    const p = yield* Path.Path

    const worktreePath = opts?.path ?? p.resolve(gitCommonDir, "..", branch)

    const args = opts?.create
      ? ["worktree", "add", "-b", branch, worktreePath]
      : ["worktree", "add", worktreePath, branch]
    yield* shell.exec("git", args, { cwd: gitCommonDir }).pipe(
      Effect.catchTag("ShellError", toGitError)
    )

    return WorktreePath(worktreePath)
  })
