import { describe, it, expect } from "bun:test"
import { Effect } from "effect"
import { ShellService, ShellError } from "../../Shell"
import { selectPane } from "./select-pane"
import { TmuxCommandError, TmuxPaneNotFoundError } from "../errors"

describe("selectPane", () => {
  it("selects pane by index", async () => {
    let calledWith: { cmd: string; args: readonly string[] } | null = null

    await Effect.runPromise(
      selectPane(2).pipe(
        Effect.provideService(ShellService, {
          exec: (cmd: string, args: readonly string[]) => {
            calledWith = { cmd, args }
            return Effect.succeed({
              stdout: "",
              stderr: "",
              exitCode: 0,
            })
          },
        } as any)
      )
    )

    expect(calledWith).toEqual({
      cmd: "tmux",
      args: ["select-pane", "-t", "2"]
    } as any)
  })

  it("converts index to string", async () => {
    let calledWith: { cmd: string; args: readonly string[] } | null = null

    await Effect.runPromise(
      selectPane(0).pipe(
        Effect.provideService(ShellService, {
          exec: (cmd: string, args: readonly string[]) => {
            calledWith = { cmd, args }
            return Effect.succeed({
              stdout: "",
              stderr: "",
              exitCode: 0,
            })
          },
        } as any)
      )
    )

    expect(calledWith).toEqual({
      cmd: "tmux",
      args: ["select-pane", "-t", "0"]
    } as any)
  })

  it("maps pane-not-found stderr to TmuxPaneNotFoundError", async () => {
    const exit = await Effect.runPromiseExit(
      selectPane(5).pipe(
        Effect.provideService(ShellService, {
          exec: () => Effect.fail(new ShellError({
            command: "tmux",
            stderr: "can't find pane: 5\n",
            stdout: "",
            exitCode: 1,
          })),
        } as any)
      )
    )

    expect(exit._tag).toBe("Failure")
    if (exit._tag === "Failure") {
      expect(exit.cause._tag).toBe("Fail")
      if (exit.cause._tag === "Fail") {
        expect(exit.cause.error).toBeInstanceOf(TmuxPaneNotFoundError)
        const error = exit.cause.error as TmuxPaneNotFoundError
        expect(error.pane).toBe("5")
      }
    }
  })

  it("maps unrecognized stderr to TmuxCommandError", async () => {
    const exit = await Effect.runPromiseExit(
      selectPane(5).pipe(
        Effect.provideService(ShellService, {
          exec: () => Effect.fail(new ShellError({
            command: "tmux",
            stderr: "server exited unexpectedly",
            stdout: "",
            exitCode: 1,
          })),
        } as any)
      )
    )

    expect(exit._tag).toBe("Failure")
    if (exit._tag === "Failure") {
      expect(exit.cause._tag).toBe("Fail")
      if (exit.cause._tag === "Fail") {
        expect(exit.cause.error).toBeInstanceOf(TmuxCommandError)
        const error = exit.cause.error as TmuxCommandError
        expect(error.operation).toBe("selectPane")
      }
    }
  })
})
