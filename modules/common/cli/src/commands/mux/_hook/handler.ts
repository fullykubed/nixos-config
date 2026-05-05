import { Effect } from "effect"
import type { Parsed } from "./command"

export const hookHandler = (_parsed: Parsed) =>
  Effect.gen(function* () {
    // Reserved for future tmux hook handling.
    // Window close events no longer need to clear DB columns since
    // tmux state is tracked via @mux_worktree_id window options.
  })
