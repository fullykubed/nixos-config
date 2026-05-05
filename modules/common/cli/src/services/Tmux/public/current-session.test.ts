import { describe, it, expect } from "bun:test"
import { Effect } from "effect"
import { ShellService, ShellError } from "../../Shell"
import { currentSession } from "./current-session"
import { TmuxCommandError, TmuxNotRunningError } from "../errors"

describe("currentSession", () => {
  it("returns session name from tmux display-message command", async () => {
    const result = await Effect.runPromise(
      currentSession().pipe(Effect.provideService(ShellService, {
        exec: () => Effect.succeed({
          stdout: "my-session\n",
          stderr: "",
          exitCode: 0,
        }),
      } as any))
    )
    expect(result).toBe("my-session")
  })

  it("trims whitespace from session name", async () => {
    const result = await Effect.runPromise(
      currentSession().pipe(Effect.provideService(ShellService, {
        exec: () => Effect.succeed({
          stdout: "  spaced-session  \n",
          stderr: "",
          exitCode: 0,
        }),
      } as any))
    )
    expect(result).toBe("spaced-session")
  })

  it("maps server-not-running stderr to TmuxNotRunningError", async () => {
    const exit = await Effect.runPromiseExit(
      currentSession().pipe(Effect.provideService(ShellService, {
        exec: () => Effect.fail(new ShellError({
          command: "tmux",
          stderr: "error connecting to /tmp/tmux-1000/default\n",
          stdout: "",
          exitCode: 1,
        })),
      } as any))
    )

    expect(exit._tag).toBe("Failure")
    if (exit._tag === "Failure") {
      expect(exit.cause._tag).toBe("Fail")
      if (exit.cause._tag === "Fail") {
        expect(exit.cause.error).toBeInstanceOf(TmuxNotRunningError)
      }
    }
  })

  it("maps unrecognized stderr to TmuxCommandError", async () => {
    const exit = await Effect.runPromiseExit(
      currentSession().pipe(Effect.provideService(ShellService, {
        exec: () => Effect.fail(new ShellError({
          command: "tmux",
          stderr: "something unexpected happened",
          stdout: "",
          exitCode: 1,
        })),
      } as any))
    )

    expect(exit._tag).toBe("Failure")
    if (exit._tag === "Failure") {
      expect(exit.cause._tag).toBe("Fail")
      if (exit.cause._tag === "Fail") {
        expect(exit.cause.error).toBeInstanceOf(TmuxCommandError)
        const error = exit.cause.error as TmuxCommandError
        expect(error.operation).toBe("currentSession")
      }
    }
  })

  it("calls tmux with correct arguments", async () => {
    let calledWith: { cmd: string; args: readonly string[] } | null = null

    await Effect.runPromise(
      currentSession().pipe(Effect.provideService(ShellService, {
        exec: (cmd: string, args: readonly string[]) => {
          calledWith = { cmd, args }
          return Effect.succeed({
            stdout: "test-session\n",
            stderr: "",
            exitCode: 0,
          })
        },
      } as any))
    )

    expect(calledWith).toEqual({
      cmd: "tmux",
      args: ["display-message", "-p", "#{session_name}"]
    } as any)
  })
})
