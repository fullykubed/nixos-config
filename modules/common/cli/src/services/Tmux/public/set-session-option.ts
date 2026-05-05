import { Effect } from "effect"
import { ShellService } from "../../Shell"
import type {} from "../errors"
import { toTmuxError } from "../errors"

/**
 * Set a user option on a tmux session.
 * If `session` is provided, targets that session with `-t`; otherwise targets the current session.
 */
export const setSessionOption = (
  key: string,
  value: string,
  session?: string,
) =>
  Effect.gen(function* () {
    const shell = yield* ShellService
    const args = session
      ? ["set-option", "-t", session, key, value]
      : ["set-option", key, value]

    yield* shell.exec("tmux", args).pipe(
      Effect.catchTag("ShellError", toTmuxError("setSessionOption"))
    )
  })
