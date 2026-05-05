import { describe, it, expect } from "bun:test"
import { Effect } from "effect"
import { ShellError } from "../Shell"
import {
  toTmuxError,
  TmuxCommandError,
  TmuxWindowNotFoundError,
  TmuxPaneNotFoundError,
  TmuxSessionNotFoundError,
  TmuxNotRunningError,
} from "./errors"

const makeShellError = (stderr: string) =>
  new ShellError({ command: "tmux", stderr, stdout: "", exitCode: 1 })

describe("toTmuxError", () => {
  it("maps 'can't find window' to TmuxWindowNotFoundError", async () => {
    const exit = await Effect.runPromiseExit(
      Effect.fail(makeShellError("can't find window: my-window\n")).pipe(
        Effect.catchAll(toTmuxError("test"))
      )
    )

    expect(exit._tag).toBe("Failure")
    if (exit._tag === "Failure" && exit.cause._tag === "Fail") {
      expect(exit.cause.error).toBeInstanceOf(TmuxWindowNotFoundError)
      expect(exit.cause.error.name).toBe("my-window")
      expect(exit.cause.error.cause).toBeDefined()
    }
  })

  it("maps 'can't find pane' to TmuxPaneNotFoundError", async () => {
    const exit = await Effect.runPromiseExit(
      Effect.fail(makeShellError("can't find pane: %5\n")).pipe(
        Effect.catchAll(toTmuxError("test"))
      )
    )

    expect(exit._tag).toBe("Failure")
    if (exit._tag === "Failure" && exit.cause._tag === "Fail") {
      expect(exit.cause.error).toBeInstanceOf(TmuxPaneNotFoundError)
      const error = exit.cause.error as TmuxPaneNotFoundError
      expect(error.pane).toBe("%5")
      expect(error.cause).toBeDefined()
    }
  })

  it("maps 'can't find session' to TmuxSessionNotFoundError", async () => {
    const exit = await Effect.runPromiseExit(
      Effect.fail(makeShellError("can't find session: my-session\n")).pipe(
        Effect.catchAll(toTmuxError("test"))
      )
    )

    expect(exit._tag).toBe("Failure")
    if (exit._tag === "Failure" && exit.cause._tag === "Fail") {
      expect(exit.cause.error).toBeInstanceOf(TmuxSessionNotFoundError)
      const error = exit.cause.error as TmuxSessionNotFoundError
      expect(error.session).toBe("my-session")
      expect(error.cause).toBeDefined()
    }
  })

  it("maps 'error connecting to' to TmuxNotRunningError", async () => {
    const exit = await Effect.runPromiseExit(
      Effect.fail(makeShellError("error connecting to /tmp/tmux-1000/default\n")).pipe(
        Effect.catchAll(toTmuxError("test"))
      )
    )

    expect(exit._tag).toBe("Failure")
    if (exit._tag === "Failure" && exit.cause._tag === "Fail") {
      expect(exit.cause.error).toBeInstanceOf(TmuxNotRunningError)
      expect(exit.cause.error.cause).toBeDefined()
    }
  })

  it("falls back to TmuxCommandError for unrecognized stderr", async () => {
    const exit = await Effect.runPromiseExit(
      Effect.fail(makeShellError("something completely unexpected")).pipe(
        Effect.catchAll(toTmuxError("myOp"))
      )
    )

    expect(exit._tag).toBe("Failure")
    if (exit._tag === "Failure" && exit.cause._tag === "Fail") {
      expect(exit.cause.error).toBeInstanceOf(TmuxCommandError)
      const error = exit.cause.error as TmuxCommandError
      expect(error.operation).toBe("myOp")
      expect(error.message).toBe("something completely unexpected")
      expect(error.cause).toBeDefined()
    }
  })

  it("preserves ShellError as cause in all error types", async () => {
    const shellError = makeShellError("can't find window: test")
    const exit = await Effect.runPromiseExit(
      Effect.fail(shellError).pipe(
        Effect.catchAll(toTmuxError("test"))
      )
    )

    expect(exit._tag).toBe("Failure")
    if (exit._tag === "Failure" && exit.cause._tag === "Fail") {
      expect(exit.cause.error.cause).toBe(shellError)
    }
  })
})
