import { Effect } from "effect"
import { ShellService } from "../../Shell"
import type {} from "../errors"
import { toTmuxError } from "../errors"
import type { TmuxWindow } from "../types"

/**
 * List all tmux windows with their index and name.
 */
export const listWindows = () =>
  Effect.gen(function* () {
    const shell = yield* ShellService
    const result = yield* shell.exec("tmux", ["list-windows", "-F", "#{window_id}:#{window_index}:#{window_name}:#{window_active}"]).pipe(
      Effect.catchTag("ShellError", toTmuxError("listWindows"))
    )

    const lines = result.stdout.trim().split("\n").filter(line => line.length > 0)

    return lines.map(line => {
      const parts = line.split(":")
      const id = parts[0] ?? ""
      const indexStr = parts[1] ?? "0"
      const activeStr = parts[parts.length - 1] ?? "0"
      const name = parts.slice(2, -1).join(":")
      const index = Number.parseInt(indexStr, 10)
      const active = activeStr === "1"
      return { id, index, name, active } satisfies TmuxWindow
    })
  })