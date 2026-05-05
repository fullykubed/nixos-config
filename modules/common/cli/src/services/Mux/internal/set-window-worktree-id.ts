import { Effect } from "effect"
import { TmuxService } from "../../Tmux"
import { type WorktreeId, MUX_WORKTREE_ID_OPTION } from "../types"
import { MuxStoreError } from "../errors"

/**
 * Tag a tmux window with its worktree DB id via a window option.
 */
export const setWindowWorktreeId = (windowId: string, worktreeId: WorktreeId) =>
  Effect.gen(function* () {
    const tmux = yield* TmuxService
    yield* tmux.setWindowOption(windowId, MUX_WORKTREE_ID_OPTION, worktreeId).pipe(
      Effect.catchAll((e) => Effect.fail(new MuxStoreError({
        operation: "setWindowWorktreeId",
        message: String(e),
      })))
    )
  })
