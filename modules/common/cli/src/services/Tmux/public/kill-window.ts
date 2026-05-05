import { Effect } from "effect"
import { ShellService } from "../../Shell"
import type {} from "../errors"
import { toTmuxError } from "../errors"

/**
 * Kill a tmux window by name.
 */
export const killWindow = (name: string) =>
  Effect.gen(function* () {
    const shell = yield* ShellService
    const args = ["kill-window", "-t", name]

    yield* shell.exec("tmux", args).pipe(
      Effect.catchTag("ShellError", toTmuxError("killWindow"))
    )
  })