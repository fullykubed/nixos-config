import { Effect } from "effect"
import { ShellService } from "../../Shell"
import type {} from "../errors"
import { toTmuxError } from "../errors"

/**
 * Focus a specific tmux pane by index.
 */
export const selectPane = (index: number) =>
  Effect.gen(function* () {
    const shell = yield* ShellService
    const args = ["select-pane", "-t", String(index)]

    yield* shell.exec("tmux", args).pipe(
      Effect.catchTag("ShellError", toTmuxError("selectPane"))
    )
  })