import { Effect } from "effect"
import { FileSystem, Path } from "@effect/platform"
import { ShellService, type ShellServiceShape } from "../../Shell"
import type { ProjectPath, WorktreePath } from "../types"
import { GitCommonPath } from "../types"
import { toGitError } from "../errors"

const execCommonDir = (shell: ShellServiceShape, cwd: string) =>
  shell.exec("git", ["rev-parse", "--path-format=absolute", "--git-common-dir"], { cwd }).pipe(
    Effect.catchTag("ShellError", toGitError),
    Effect.map(({ stdout }) => GitCommonPath(stdout.trim())),
  )

export const commonDir = (cwd: ProjectPath | WorktreePath) =>
  Effect.gen(function* () {
    const shell = yield* ShellService
    return yield* execCommonDir(shell, cwd).pipe(
      Effect.catchAll((notRepoErr) =>
        Effect.gen(function* () {
          const fs = yield* FileSystem.FileSystem
          const p = yield* Path.Path
          const barePath = p.join(cwd, ".bare")
          const stat = yield* fs.stat(barePath).pipe(Effect.catchAll(() => Effect.succeed(null)))
          if (stat?.type !== "Directory") return yield* Effect.fail(notRepoErr)
          return yield* execCommonDir(shell, barePath)
        })
      ),
    )
  })
