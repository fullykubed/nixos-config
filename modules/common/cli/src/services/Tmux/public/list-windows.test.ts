import { describe, it, expect } from "bun:test"
import { Effect } from "effect"
import { ShellService, ShellError } from "../../Shell"
import { listWindows } from "./list-windows"
import { TmuxCommandError, TmuxNotRunningError } from "../errors"

describe("listWindows", () => {
  it("parses tmux list-windows output correctly", async () => {
    const result = await Effect.runPromise(
      listWindows().pipe(Effect.provideService(ShellService, {
        exec: () => Effect.succeed({
          stdout: "@0:0:main:1\n@1:1:\uf418 vim:0\n@2:2:shell:0\n",
          stderr: "",
          exitCode: 0,
        }),
      } as any))
    )

    expect(result).toEqual([
      { id: "@0", index: 0, name: "main", active: true },
      { id: "@1", index: 1, name: "\uf418 vim", active: false },
      { id: "@2", index: 2, name: "shell", active: false },
    ])
  })

  it("handles window names with colons", async () => {
    const result = await Effect.runPromise(
      listWindows().pipe(Effect.provideService(ShellService, {
        exec: () => Effect.succeed({
          stdout: "@0:0:main:0\n@1:1:vim:config:0\n@2:2:ssh:host:123:1\n",
          stderr: "",
          exitCode: 0,
        }),
      } as any))
    )

    expect(result).toEqual([
      { id: "@0", index: 0, name: "main", active: false },
      { id: "@1", index: 1, name: "vim:config", active: false },
      { id: "@2", index: 2, name: "ssh:host:123", active: true },
    ])
  })

  it("filters out empty lines", async () => {
    const result = await Effect.runPromise(
      listWindows().pipe(Effect.provideService(ShellService, {
        exec: () => Effect.succeed({
          stdout: "@0:0:main:1\n\n@1:1:vim:0\n\n",
          stderr: "",
          exitCode: 0,
        }),
      } as any))
    )

    expect(result).toEqual([
      { id: "@0", index: 0, name: "main", active: true },
      { id: "@1", index: 1, name: "vim", active: false },
    ])
  })

  it("returns empty array for no windows", async () => {
    const result = await Effect.runPromise(
      listWindows().pipe(Effect.provideService(ShellService, {
        exec: () => Effect.succeed({
          stdout: "",
          stderr: "",
          exitCode: 0,
        }),
      } as any))
    )

    expect(result).toEqual([])
  })

  it("calls tmux with correct arguments", async () => {
    let calledWith: { cmd: string; args: readonly string[] } | null = null

    await Effect.runPromise(
      listWindows().pipe(Effect.provideService(ShellService, {
        exec: (cmd: string, args: readonly string[]) => {
          calledWith = { cmd, args }
          return Effect.succeed({
            stdout: "@0:0:main:1\n",
            stderr: "",
            exitCode: 0,
          })
        },
      } as any))
    )

    expect(calledWith).toEqual({
      cmd: "tmux",
      args: ["list-windows", "-F", "#{window_id}:#{window_index}:#{window_name}:#{window_active}"]
    } as any)
  })

  it("maps server-not-running stderr to TmuxNotRunningError", async () => {
    const exit = await Effect.runPromiseExit(
      listWindows().pipe(
        Effect.provideService(ShellService, {
          exec: () => Effect.fail(new ShellError({
            command: "tmux",
            stderr: "error connecting to /tmp/tmux-1000/default\n",
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
        expect(exit.cause.error).toBeInstanceOf(TmuxNotRunningError)
      }
    }
  })

  it("maps unrecognized stderr to TmuxCommandError", async () => {
    const exit = await Effect.runPromiseExit(
      listWindows().pipe(
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
        expect(error.operation).toBe("listWindows")
      }
    }
  })
})
