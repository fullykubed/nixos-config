import { Effect } from "effect"
import { ShellService } from "../../Shell"
import { TmuxService } from "../../Tmux"
import { type WorktreeId, MUX_WORKTREE_ID_OPTION } from "../types"

/**
 * Find and kill the tmux window tagged with the given worktree id.
 * Returns true if a window was killed, false if none was found.
 */
export const killWindowByWorktreeId = (worktreeId: WorktreeId) =>
  Effect.gen(function* () {
    const shell = yield* ShellService
    const tmux = yield* TmuxService

    // List windows including the worktree id user option (tab-separated)
    const result = yield* shell.exec("tmux", [
      "list-windows", "-F", `#{window_id}\t#{${MUX_WORKTREE_ID_OPTION}}`,
    ]).pipe(Effect.catchAll(() => Effect.succeed({ stdout: "", stderr: "", exitCode: 0 })))

    const lines = result.stdout.trim().split("\n").filter(l => l.length > 0)

    for (const line of lines) {
      const [winId, wtId] = line.split("\t")
      if (wtId === worktreeId && winId) {
        yield* tmux.killWindow(winId)
        return true
      }
    }

    return false
  })
