import { Effect } from "effect"
import { ShellService } from "../../Shell"
import type {} from "../errors"
import { toTmuxError } from "../errors"

/**
 * Send keystrokes to a tmux pane followed by Enter.
 */
export const sendKeys = (target: string, keys: string) =>
  Effect.gen(function* () {
    const shell = yield* ShellService
    const args = ["send-keys", "-t", target, keys, "Enter"]

    yield* shell.exec("tmux", args).pipe(
      Effect.catchTag("ShellError", toTmuxError("sendKeys"))
    )
  })