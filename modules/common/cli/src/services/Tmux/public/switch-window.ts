import { Effect } from "effect"
import { ShellService } from "../../Shell"
import type {} from "../errors"
import { toTmuxError } from "../errors"

/**
 * Switch to a tmux window by name.
 */
export const switchWindow = (name: string) =>
  Effect.gen(function* () {
    const shell = yield* ShellService
    const args = ["select-window", "-t", name]

    yield* shell.exec("tmux", args).pipe(
      Effect.catchTag("ShellError", toTmuxError("switchWindow"))
    )
  })