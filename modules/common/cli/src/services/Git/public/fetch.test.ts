import { describe, it, expect } from "bun:test"
import { Effect, Exit } from "effect"
import { fetch } from "./fetch"
import { GitCommonPath } from "../types"
import { ShellService, ShellError } from "../../Shell"

describe("fetch", () => {
  it("should execute git fetch with remote name", async () => {
    let capturedArgs: string[] = []
    const shell = ShellService.of({
      exec: (cmd, args) => {
        capturedArgs = [cmd, ...args]
        return Effect.succeed({ stdout: "", stderr: "", exitCode: 0 })
      },
      execJson: () => Effect.succeed({}) as any,
      execLines: () => Effect.succeed([]) as any,
    })

    await Effect.runPromise(
      fetch("origin", GitCommonPath("/repo/.git")).pipe(Effect.provideService(ShellService, shell))
    )

    expect(capturedArgs).toEqual(["git", "fetch", "origin"])
  })

  it("should pass cwd option to shell", async () => {
    let capturedOpts: any = undefined
    const shell = ShellService.of({
      exec: (_cmd, _args, opts) => {
        capturedOpts = opts
        return Effect.succeed({ stdout: "", stderr: "", exitCode: 0 })
      },
      execJson: () => Effect.succeed({}) as any,
      execLines: () => Effect.succeed([]) as any,
    })

    await Effect.runPromise(
      fetch("origin", GitCommonPath("/some/cwd")).pipe(Effect.provideService(ShellService, shell))
    )

    expect(capturedOpts).toEqual({ cwd: "/some/cwd" })
  })

  it("should fail with GitNotRepoError when not a git repo", async () => {
    const shell = ShellService.of({
      exec: () => Effect.fail(new ShellError({
        command: "git fetch origin",
        exitCode: 1,
        stderr: "fatal: not a git repository",
        stdout: "",
      })),
      execJson: () => Effect.succeed({}) as any,
      execLines: () => Effect.succeed([]) as any,
    })

    const exit = await Effect.runPromiseExit(
      fetch("origin", GitCommonPath("/repo/.git")).pipe(Effect.provideService(ShellService, shell))
    )

    expect(Exit.isFailure(exit)).toBe(true)
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      expect(exit.cause.error._tag).toBe("GitNotRepoError")
    }
  })

  it("should fail with GitConnectivityError on network errors", async () => {
    const shell = ShellService.of({
      exec: () => Effect.fail(new ShellError({
        command: "git fetch origin",
        exitCode: 128,
        stderr: "fatal: Could not resolve host github.com",
        stdout: "",
      })),
      execJson: () => Effect.succeed({}) as any,
      execLines: () => Effect.succeed([]) as any,
    })

    const exit = await Effect.runPromiseExit(
      fetch("origin", GitCommonPath("/repo/.git")).pipe(Effect.provideService(ShellService, shell))
    )

    expect(Exit.isFailure(exit)).toBe(true)
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      expect(exit.cause.error._tag).toBe("GitConnectivityError")
    }
  })

  it("should fail with GitAuthError on permission denied", async () => {
    const shell = ShellService.of({
      exec: () => Effect.fail(new ShellError({
        command: "git fetch origin",
        exitCode: 128,
        stderr: "Permission denied (publickey)",
        stdout: "",
      })),
      execJson: () => Effect.succeed({}) as any,
      execLines: () => Effect.succeed([]) as any,
    })

    const exit = await Effect.runPromiseExit(
      fetch("origin", GitCommonPath("/repo/.git")).pipe(Effect.provideService(ShellService, shell))
    )

    expect(Exit.isFailure(exit)).toBe(true)
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      expect(exit.cause.error._tag).toBe("GitAuthError")
    }
  })

  it("should fail with GitUnknownError on other errors", async () => {
    const shell = ShellService.of({
      exec: () => Effect.fail(new ShellError({
        command: "git fetch origin",
        exitCode: 1,
        stderr: "fatal: some unexpected error",
        stdout: "",
      })),
      execJson: () => Effect.succeed({}) as any,
      execLines: () => Effect.succeed([]) as any,
    })

    const exit = await Effect.runPromiseExit(
      fetch("origin", GitCommonPath("/repo/.git")).pipe(Effect.provideService(ShellService, shell))
    )

    expect(Exit.isFailure(exit)).toBe(true)
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      expect(exit.cause.error._tag).toBe("GitUnknownError")
    }
  })
})
