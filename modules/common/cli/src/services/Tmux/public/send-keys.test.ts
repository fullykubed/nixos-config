import { describe, it, expect } from "bun:test"
import { Effect } from "effect"
import { ShellService, ShellError } from "../../Shell"
import { sendKeys } from "./send-keys"
import { TmuxCommandError, TmuxPaneNotFoundError } from "../errors"

describe("sendKeys", () => {
  it("sends keys to target pane with Enter", async () => {
    let calledWith: { cmd: string; args: readonly string[] } | null = null

    await Effect.runPromise(
      sendKeys("1", "ls -la").pipe(
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
      args: ["send-keys", "-t", "1", "ls -la", "Enter"]
    } as any)
  })

  it("handles special characters in keys", async () => {
    let calledWith: { cmd: string; args: readonly string[] } | null = null

    await Effect.runPromise(
      sendKeys("0", "echo 'hello world' && exit").pipe(
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
      args: ["send-keys", "-t", "0", "echo 'hello world' && exit", "Enter"]
    } as any)
  })

  it("maps pane-not-found stderr to TmuxPaneNotFoundError", async () => {
    const exit = await Effect.runPromiseExit(
      sendKeys("1", "test").pipe(
        Effect.provideService(ShellService, {
          exec: () => Effect.fail(new ShellError({
            command: "tmux",
            stderr: "can't find pane: 1\n",
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
        expect(exit.cause.error).toBeInstanceOf(TmuxPaneNotFoundError)
        const error = exit.cause.error as TmuxPaneNotFoundError
        expect(error.pane).toBe("1")
      }
    }
  })

  it("maps unrecognized stderr to TmuxCommandError", async () => {
    const exit = await Effect.runPromiseExit(
      sendKeys("1", "test").pipe(
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
        expect(error.operation).toBe("sendKeys")
      }
    }
  })
})
