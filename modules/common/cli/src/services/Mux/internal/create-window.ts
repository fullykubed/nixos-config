import { Effect } from "effect"
import { Path } from "@effect/platform"
import { TmuxService } from "../../Tmux"
import type { BranchName, WorktreePath, PaneDefinition } from "../../Git"
import type { WorktreeId } from "../types"
import { setWindowWorktreeId } from "./set-window-worktree-id"

/**
 * Create a tmux window for a worktree branch with panes from config.
 * Tags the window with the worktree id and returns the window ID.
 */
export const createWindow = (
  branch: BranchName,
  worktreePath: WorktreePath,
  panes: readonly PaneDefinition[],
  worktreeId: WorktreeId,
) =>
  Effect.gen(function* () {
    const tmux = yield* TmuxService
    const path = yield* Path.Path
    let focusIndex = 0

    const windowName = path.basename(worktreePath)

    if (panes.length === 0) {
      const windowId = yield* tmux.createWindow({
        name: windowName,
        cwd: worktreePath,
      })
      yield* setWindowWorktreeId(windowId, worktreeId)

      return windowId
    }

    const firstPane = panes[0]!

    // Create window (starts user's shell), then send command via keys
    const windowId = yield* tmux.createWindow({
      name: windowName,
      cwd: worktreePath,
    })

    if (firstPane.command) {
      yield* tmux.sendKeys(windowId, firstPane.command)
    }

    if (firstPane.focus) {
      focusIndex = 0
    }

    // For each subsequent pane: split, send command if exists
    yield* Effect.forEach(panes.slice(1), (pane, i) =>
      Effect.gen(function* () {
        yield* tmux.splitPane({
          direction: pane.split ?? "horizontal",
          percentage: pane.percentage,
          cwd: worktreePath,
        })
        if (pane.command) {
          yield* tmux.sendKeys(`{last}`, pane.command)
        }
        if (pane.focus) {
          focusIndex = i + 1
        }
      }),
      { discard: true }
    )

    // Focus the designated pane (splitPane leaves focus on the last-created pane)
    yield* tmux.selectPane(focusIndex)

    yield* setWindowWorktreeId(windowId, worktreeId)
    yield* Effect.log(`Created window for worktree: ${branch}`)
    return windowId
  })
