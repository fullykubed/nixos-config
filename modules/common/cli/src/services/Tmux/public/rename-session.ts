import { Effect } from "effect"
import { ShellService } from "../../Shell"
import type {} from "../errors"
import { toTmuxError } from "../errors"

/**
 * Rename a tmux session.
 */
export const renameSession = (
  oldName: string,
  newName: string,
) =>
  Effect.gen(function* () {
    const shell = yield* ShellService

    yield* shell.exec("tmux", ["rename-session", "-t", oldName, newName]).pipe(
      Effect.catchTag("ShellError", toTmuxError("renameSession"))
    )
  })
