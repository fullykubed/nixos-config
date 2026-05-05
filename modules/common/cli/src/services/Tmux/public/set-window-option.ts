import { Effect } from "effect"
import { ShellService } from "../../Shell"
import type {} from "../errors"
import { toTmuxError } from "../errors"

/**
 * Set a user option on a tmux window.
 * Uses `tmux set-option -w -t <target> <key> <value>`.
 */
export const setWindowOption = (
  target: string,
  key: string,
  value: string,
) =>
  Effect.gen(function* () {
    const shell = yield* ShellService
    const args = ["set-option", "-w", "-t", target, key, value]

    yield* shell.exec("tmux", args).pipe(
      Effect.catchTag("ShellError", toTmuxError("setWindowOption"))
    )
  })
