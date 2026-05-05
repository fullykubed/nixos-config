import { Effect } from "effect"
import { ShellService } from "../../Shell"
import type {} from "../errors"
import { toTmuxError } from "../errors"

/**
 * Get the name of the current tmux session.
 */
export const currentSession = () =>
  Effect.gen(function* () {
    const shell = yield* ShellService
    const result = yield* shell.exec("tmux", ["display-message", "-p", "#{session_name}"]).pipe(
      Effect.catchTag("ShellError", toTmuxError("currentSession"))
    )
    return result.stdout.trim()
  })