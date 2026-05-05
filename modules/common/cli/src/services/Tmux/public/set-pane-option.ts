import { Effect } from "effect"
import { ShellService } from "../../Shell"
import type {} from "../errors"
import { toTmuxError } from "../errors"

/**
 * Set a user option on a tmux pane.
 * Uses `tmux set-option -p -t <target> <key> <value>`.
 */
export const setPaneOption = (
  target: string,
  key: string,
  value: string,
) =>
  Effect.gen(function* () {
    const shell = yield* ShellService
    const args = ["set-option", "-p", "-t", target, key, value]

    yield* shell.exec("tmux", args).pipe(
      Effect.catchTag("ShellError", toTmuxError("setPaneOption"))
    )
  })
