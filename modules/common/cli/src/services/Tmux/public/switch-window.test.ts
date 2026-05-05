import { describe, it, expect } from "bun:test"
import { Effect } from "effect"
import { ShellService, ShellError } from "../../Shell"
import { switchWindow } from "./switch-window"
import { TmuxCommandError, TmuxWindowNotFoundError } from "../errors"

describe("switchWindow", () => {
  it("switches to window by name", async () => {
    let calledWith: { cmd: string; args: readonly string[] } | null = null

    await Effect.runPromise(
      switchWindow("vim").pipe(
        Effect.provideService(ShellService, {
          exec: (cmd: string, args: readonly string[]) => {
            calledWith = { cmd, args }
            return Effect.succeed({
              stdout: "",
              stderr: "",
              exitCode: 0,
            })
          },
          execJson: () => Effect.succeed({} as any),
          execLines: () => Effect.succeed([]),
        })
      )
    )

    expect(calledWith).toEqual({
      cmd: "tmux",
      args: ["select-window", "-t", "vim"]
    } as any)
  })

  it("handles window names with special characters", async () => {
    let calledWith: { cmd: string; args: readonly string[] } | null = null

    await Effect.runPromise(
      switchWindow("\uf418 feature-branch").pipe(
        Effect.provideService(ShellService, {
          exec: (cmd: string, args: readonly string[]) => {
            calledWith = { cmd, args }
            return Effect.succeed({
              stdout: "",
              stderr: "",
              exitCode: 0,
            })
          },
          execJson: () => Effect.succeed({} as any),
          execLines: () => Effect.succeed([]),
        })
      )
    )

    expect(calledWith).toEqual({
      cmd: "tmux",
      args: ["select-window", "-t", "\uf418 feature-branch"]
    } as any)
  })

  it("maps window-not-found stderr to TmuxWindowNotFoundError", async () => {
    const exit = await Effect.runPromiseExit(
      switchWindow("nonexistent").pipe(
        Effect.provideService(ShellService, {
          exec: () => Effect.fail(new ShellError({
            command: "tmux",
            stderr: "can't find window: nonexistent\n",
            stdout: "",
            exitCode: 1,
          })),
          execJson: () => Effect.succeed({} as any),
          execLines: () => Effect.succeed([]),
        })
      )
    )

    expect(exit._tag).toBe("Failure")
    if (exit._tag === "Failure") {
      expect(exit.cause._tag).toBe("Fail")
      if (exit.cause._tag === "Fail") {
        expect(exit.cause.error).toBeInstanceOf(TmuxWindowNotFoundError)
        expect(exit.cause.error.name).toBe("nonexistent")
      }
    }
  })

  it("maps unrecognized stderr to TmuxCommandError", async () => {
    const exit = await Effect.runPromiseExit(
      switchWindow("nonexistent").pipe(
        Effect.provideService(ShellService, {
          exec: () => Effect.fail(new ShellError({
            command: "tmux",
            stderr: "server exited unexpectedly",
            stdout: "",
            exitCode: 1,
          })),
          execJson: () => Effect.succeed({} as any),
          execLines: () => Effect.succeed([]),
        })
      )
    )

    expect(exit._tag).toBe("Failure")
    if (exit._tag === "Failure") {
      expect(exit.cause._tag).toBe("Fail")
      if (exit.cause._tag === "Fail") {
        expect(exit.cause.error).toBeInstanceOf(TmuxCommandError)
        const error = exit.cause.error as TmuxCommandError
        expect(error.operation).toBe("switchWindow")
      }
    }
  })
})
