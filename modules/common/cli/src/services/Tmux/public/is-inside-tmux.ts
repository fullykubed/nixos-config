import { Effect } from "effect"

/**
 * Check if the current process is running inside a tmux session.
 * Returns true if the TMUX environment variable is set, false otherwise.
 */
export const isInsideTmux = () =>
  Effect.sync(() => Boolean(process.env.TMUX))