import { describe, it, expect } from "bun:test"
import { Effect } from "effect"
import { ShellService, ShellError } from "../../Shell"
import { createWindow } from "./create-window"
import { TmuxCommandError, TmuxSessionNotFoundError } from "../errors"
import { WINDOW_PREFIX } from "../config"

describe("createWindow", () => {
  it("creates window with name and cwd, returns window ID", async () => {
    let calledWith: { cmd: string; args: readonly string[] } | null = null

    const result = await Effect.runPromise(
      createWindow({ name: "test", cwd: "/home/user" }).pipe(
        Effect.provideService(ShellService, {
          exec: (cmd: string, args: readonly string[]) => {
            calledWith = { cmd, args }
            return Effect.succeed({
              stdout: "@1\n",
              stderr: "",
              exitCode: 0,
            })
          },
        } as any)
      )
    )

    expect(calledWith).toEqual({
      cmd: "tmux",
      args: ["new-window", "-P", "-F", "#{window_id}", "-n", `${WINDOW_PREFIX}test`, "-c", "/home/user"]
    } as any)
    expect(result).toBe("@1")
  })

  it("creates window with name, cwd, and command", async () => {
    let calledWith: { cmd: string; args: readonly string[] } | null = null

    const result = await Effect.runPromise(
      createWindow({ name: "test", cwd: "/home/user", command: "vim" }).pipe(
        Effect.provideService(ShellService, {
          exec: (cmd: string, args: readonly string[]) => {
            calledWith = { cmd, args }
            return Effect.succeed({
              stdout: "@2\n",
              stderr: "",
              exitCode: 0,
            })
          },
        } as any)
      )
    )

    expect(calledWith).toEqual({
      cmd: "tmux",
      args: ["new-window", "-P", "-F", "#{window_id}", "-n", `${WINDOW_PREFIX}test`, "-c", "/home/user", "vim"]
    } as any)
    expect(result).toBe("@2")
  })

  it("adds window prefix to name", async () => {
    let calledWith: { cmd: string; args: readonly string[] } | null = null

    await Effect.runPromise(
      createWindow({ name: "my-window", cwd: "/tmp" }).pipe(
        Effect.provideService(ShellService, {
          exec: (cmd: string, args: readonly string[]) => {
            calledWith = { cmd, args }
            return Effect.succeed({
              stdout: "@0\n",
              stderr: "",
              exitCode: 0,
            })
          },
        } as any)
      )
    )

    expect(calledWith!.args[5]).toBe(`${WINDOW_PREFIX}my-window`)
  })

  it("maps session-not-found stderr to TmuxSessionNotFoundError", async () => {
    const exit = await Effect.runPromiseExit(
      createWindow({ name: "test", cwd: "/tmp" }).pipe(
        Effect.provideService(ShellService, {
          exec: () => Effect.fail(new ShellError({
            command: "tmux",
            stderr: "can't find session: nonexistent\n",
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
        expect(exit.cause.error).toBeInstanceOf(TmuxSessionNotFoundError)
        const error = exit.cause.error as TmuxSessionNotFoundError
        expect(error.session).toBe("nonexistent")
      }
    }
  })

  it("maps unrecognized stderr to TmuxCommandError", async () => {
    const exit = await Effect.runPromiseExit(
      createWindow({ name: "test", cwd: "/tmp" }).pipe(
        Effect.provideService(ShellService, {
          exec: () => Effect.fail(new ShellError({
            command: "tmux",
            stderr: "something unexpected happened",
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
        expect(error.operation).toBe("createWindow")
        expect(error.message).toBe("something unexpected happened")
      }
    }
  })
})
