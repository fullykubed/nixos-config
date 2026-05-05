import { Effect } from "effect"
import { ShellService } from "../../Shell"
import type {} from "../errors"
import { toTmuxError } from "../errors"

/**
 * Ensure a tmux session exists. If a session with the given name already
 * exists, this is a no-op. Otherwise, creates a detached session.
 */
export const ensureSession = (
  name: string,
) =>
  Effect.gen(function* () {
    const shell = yield* ShellService

    const exists = yield* shell.exec("tmux", ["has-session", "-t", name]).pipe(
      Effect.map(() => true),
      Effect.catchTag("ShellError", () => Effect.succeed(false)),
    )

    if (!exists) {
      yield* shell.exec("tmux", ["new-session", "-d", "-s", name]).pipe(
        Effect.catchTag("ShellError", toTmuxError("ensureSession"))
      )
    }
  })
