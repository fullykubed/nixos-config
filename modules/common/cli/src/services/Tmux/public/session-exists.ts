import { Effect } from "effect"
import { ShellService } from "../../Shell"

/**
 * Check whether a tmux session with the given name exists.
 */
export const sessionExists = (
  name: string,
) =>
  Effect.gen(function* () {
    const shell = yield* ShellService

    return yield* shell.exec("tmux", ["has-session", "-t", name]).pipe(
      Effect.map(() => true),
      Effect.catchAll(() => Effect.succeed(false)),
    )
  })
