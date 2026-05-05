import { Effect } from "effect"
import { ShellService } from "../../Shell"
import type {} from "../errors"
import { toTmuxError } from "../errors"
import type { SplitPaneOptions } from "../types"

/**
 * Split the current tmux pane in the specified direction with optional percentage and working directory.
 */
export const splitPane = (opts: SplitPaneOptions) =>
  Effect.gen(function* () {
    const shell = yield* ShellService
    const args = ["split-window"]

    // Add direction flag
    args.push(opts.direction === "horizontal" ? "-h" : "-v")

    // Add percentage if specified
    if (opts.percentage !== undefined) {
      args.push("-p", String(opts.percentage))
    }

    // Add working directory if specified
    if (opts.cwd) {
      args.push("-c", opts.cwd)
    }

    // Add target if specified
    if (opts.target) {
      args.push("-t", opts.target)
    }

    yield* shell.exec("tmux", args).pipe(
      Effect.catchTag("ShellError", toTmuxError("splitPane"))
    )
  })