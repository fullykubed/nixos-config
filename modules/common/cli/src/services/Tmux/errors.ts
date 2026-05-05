import { Data, Effect } from "effect"
import type { ShellError } from "../Shell/errors"

export class NotInsideTmuxError extends Data.TaggedError("NotInsideTmuxError")<{
  readonly message: string
  readonly cause?: unknown
}> {}

export class TmuxCommandError extends Data.TaggedError("TmuxCommandError")<{
  readonly operation: string
  readonly message: string
  readonly cause?: ShellError
}> {}

export class TmuxWindowNotFoundError extends Data.TaggedError("TmuxWindowNotFoundError")<{
  readonly name: string
  readonly cause?: ShellError
}> {}

export class TmuxPaneNotFoundError extends Data.TaggedError("TmuxPaneNotFoundError")<{
  readonly pane: string
  readonly cause?: ShellError
}> {}

export class TmuxSessionNotFoundError extends Data.TaggedError("TmuxSessionNotFoundError")<{
  readonly session: string
  readonly cause?: ShellError
}> {}

export class TmuxNotRunningError extends Data.TaggedError("TmuxNotRunningError")<{
  readonly cause?: ShellError
}> {}

export type TmuxError =
  | TmuxWindowNotFoundError
  | TmuxPaneNotFoundError
  | TmuxSessionNotFoundError
  | TmuxNotRunningError
  | TmuxCommandError

/** Map a ShellError to the appropriate Tmux error, detecting window/pane/session not found and server not running. */
export const toTmuxError = (operation: string) =>
  (e: ShellError) => {
    const windowMatch = /can't find window: (.+)/.exec(e.stderr)
    if (windowMatch) {
      return Effect.fail<TmuxError>(new TmuxWindowNotFoundError({ name: windowMatch[1]?.trim() ?? "", cause: e }))
    }
    const paneMatch = /can't find pane: (.+)/.exec(e.stderr)
    if (paneMatch) {
      return Effect.fail<TmuxError>(new TmuxPaneNotFoundError({ pane: paneMatch[1]?.trim() ?? "", cause: e }))
    }
    const sessionMatch = /can't find session: (.+)/.exec(e.stderr)
    if (sessionMatch) {
      return Effect.fail<TmuxError>(new TmuxSessionNotFoundError({ session: sessionMatch[1]?.trim() ?? "", cause: e }))
    }
    if (e.stderr.includes("error connecting to")) {
      return Effect.fail<TmuxError>(new TmuxNotRunningError({ cause: e }))
    }
    return Effect.fail<TmuxError>(new TmuxCommandError({ operation, message: e.stderr, cause: e }))
  }
