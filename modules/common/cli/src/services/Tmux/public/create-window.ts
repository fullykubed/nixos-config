import { Effect } from "effect"
import { ShellService } from "../../Shell"
import type {} from "../errors"
import { toTmuxError } from "../errors"
import { WINDOW_PREFIX } from "../config"
import type { CreateWindowOptions } from "../types"

/**
 * Create a new tmux window with the specified name, working directory, and optional command.
 */
export const createWindow = (opts: CreateWindowOptions) =>
  Effect.gen(function* () {
    const shell = yield* ShellService
    const windowName = `${WINDOW_PREFIX}${opts.name}`
    const args = ["new-window", "-P", "-F", "#{window_id}", "-n", windowName, "-c", opts.cwd]
    if (opts.command) {
      args.push(opts.command)
    }

    const result = yield* shell.exec("tmux", args).pipe(
      Effect.catchTag("ShellError", toTmuxError("createWindow"))
    )
    return result.stdout.trim()
  })