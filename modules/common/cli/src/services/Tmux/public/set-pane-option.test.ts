import { describe, it, expect } from "bun:test"
import { Effect } from "effect"
import { ShellService, ShellError } from "../../Shell"
import { setPaneOption } from "./set-pane-option"
import { TmuxCommandError } from "../errors"

describe("setPaneOption", () => {
  it("invokes set-option -p with target, key, and value", async () => {
    let calledWith: { cmd: string; args: readonly string[] } | null = null

    await Effect.runPromise(
      setPaneOption("session:window.0", "@mykey", "myvalue").pipe(
        Effect.provideService(ShellService, {
          exec: (cmd: string, args: readonly string[]) => {
            calledWith = { cmd, args }
            return Effect.succeed({ stdout: "", stderr: "", exitCode: 0 })
          },
          execJson: () => Effect.succeed({} as any),
          execLines: () => Effect.succeed([]),
        })
      )
    )

    expect(calledWith).toEqual({
      cmd: "tmux",
      args: ["set-option", "-p", "-t", "session:window.0", "@mykey", "myvalue"],
    } as any)
  })

  it("maps unrecognized stderr to TmuxCommandError", async () => {
    const exit = await Effect.runPromiseExit(
      setPaneOption("session:window.0", "@mykey", "myvalue").pipe(
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
    if (exit._tag === "Failure" && exit.cause._tag === "Fail") {
      expect(exit.cause.error).toBeInstanceOf(TmuxCommandError)
      const error = exit.cause.error as TmuxCommandError
        expect(error.operation).toBe("setPaneOption")
    }
  })
})
