import { describe, it, expect } from "bun:test"
import { Effect } from "effect"
import { ShellService, ShellError } from "../../Shell"
import { splitPane } from "./split-pane"
import { TmuxCommandError, TmuxWindowNotFoundError } from "../errors"

describe("splitPane", () => {
  it("splits horizontally", async () => {
    let calledWith: { cmd: string; args: readonly string[] } | null = null

    await Effect.runPromise(
      splitPane({ direction: "horizontal" }).pipe(
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
      args: ["split-window", "-h"]
    } as any)
  })

  it("splits vertically", async () => {
    let calledWith: { cmd: string; args: readonly string[] } | null = null

    await Effect.runPromise(
      splitPane({ direction: "vertical" }).pipe(
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
      args: ["split-window", "-v"]
    } as any)
  })

  it("includes percentage when specified", async () => {
    let calledWith: { cmd: string; args: readonly string[] } | null = null

    await Effect.runPromise(
      splitPane({ direction: "horizontal", percentage: 30 }).pipe(
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
      args: ["split-window", "-h", "-p", "30"]
    } as any)
  })

  it("includes cwd when specified", async () => {
    let calledWith: { cmd: string; args: readonly string[] } | null = null

    await Effect.runPromise(
      splitPane({ direction: "vertical", cwd: "/home/user" }).pipe(
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
      args: ["split-window", "-v", "-c", "/home/user"]
    } as any)
  })

  it("includes target when specified", async () => {
    let calledWith: { cmd: string; args: readonly string[] } | null = null

    await Effect.runPromise(
      splitPane({ direction: "horizontal", target: "1" }).pipe(
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
      args: ["split-window", "-h", "-t", "1"]
    } as any)
  })

  it("includes all options when specified", async () => {
    let calledWith: { cmd: string; args: readonly string[] } | null = null

    await Effect.runPromise(
      splitPane({
        direction: "vertical",
        percentage: 25,
        cwd: "/tmp",
        target: "0"
      }).pipe(
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
      args: ["split-window", "-v", "-p", "25", "-c", "/tmp", "-t", "0"]
    } as any)
  })

  it("maps window-not-found stderr to TmuxWindowNotFoundError", async () => {
    const exit = await Effect.runPromiseExit(
      splitPane({ direction: "horizontal", target: "nonexistent" }).pipe(
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
      splitPane({ direction: "horizontal" }).pipe(
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
        expect(error.operation).toBe("splitPane")
      }
    }
  })
})
