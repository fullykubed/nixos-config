import { describe, it, expect } from "bun:test"
import { Effect, Exit } from "effect"
import { hasRemote } from "./has-remote"
import { GitCommonPath } from "../types"
import { ShellService, ShellError } from "../../Shell"

describe("hasRemote", () => {
  it("should return true when remote has a URL", async () => {
    const shell = ShellService.of({
      exec: () => Effect.succeed({ stdout: "git@github.com:user/repo.git\n", stderr: "", exitCode: 0 }),
      execJson: () => Effect.succeed({}) as any,
      execLines: () => Effect.succeed([]) as any,
    })
    const result = await Effect.runPromise(
      hasRemote("origin", GitCommonPath("/repo/.git")).pipe(Effect.provideService(ShellService, shell))
    )
    expect(result).toBe(true)
  })

  it("should return false when remote does not exist", async () => {
    const shell = ShellService.of({
      exec: () => Effect.fail(new ShellError({
        command: "git remote get-url upstream",
        exitCode: 2,
        stderr: "error: No such remote 'upstream'",
        stdout: "",
      })),
      execJson: () => Effect.succeed({}) as any,
      execLines: () => Effect.succeed([]) as any,
    })
    const result = await Effect.runPromise(
      hasRemote("upstream", GitCommonPath("/repo/.git")).pipe(Effect.provideService(ShellService, shell))
    )
    expect(result).toBe(false)
  })

  it("should return false when remote has no URL (phantom from global config)", async () => {
    const shell = ShellService.of({
      exec: () => Effect.fail(new ShellError({
        command: "git remote get-url origin",
        exitCode: 2,
        stderr: "error: No such remote 'origin'",
        stdout: "",
      })),
      execJson: () => Effect.succeed({}) as any,
      execLines: () => Effect.succeed([]) as any,
    })
    const result = await Effect.runPromise(
      hasRemote("origin", GitCommonPath("/repo/.git")).pipe(Effect.provideService(ShellService, shell))
    )
    expect(result).toBe(false)
  })

  it("should pass cwd option to shell", async () => {
    let capturedOpts: any = undefined
    const shell = ShellService.of({
      exec: (_cmd, _args, opts) => {
        capturedOpts = opts
        return Effect.succeed({ stdout: "git@github.com:user/repo.git\n", stderr: "", exitCode: 0 })
      },
      execJson: () => Effect.succeed({}) as any,
      execLines: () => Effect.succeed([]) as any,
    })

    await Effect.runPromise(
      hasRemote("origin", GitCommonPath("/some/path")).pipe(Effect.provideService(ShellService, shell))
    )

    expect(capturedOpts).toEqual({ cwd: "/some/path" })
  })

  it("should verify correct remote name is passed to git", async () => {
    let capturedArgs: string[] = []
    const shell = ShellService.of({
      exec: (_cmd, args) => {
        capturedArgs = [...args]
        return Effect.succeed({ stdout: "git@github.com:user/repo.git\n", stderr: "", exitCode: 0 })
      },
      execJson: () => Effect.succeed({}) as any,
      execLines: () => Effect.succeed([]) as any,
    })

    await Effect.runPromise(
      hasRemote("upstream", GitCommonPath("/repo/.git")).pipe(Effect.provideService(ShellService, shell))
    )

    expect(capturedArgs).toEqual(["remote", "get-url", "upstream"])
  })

  it("should fail with GitNotRepoError when not a git repo", async () => {
    const shell = ShellService.of({
      exec: () => Effect.fail(new ShellError({
        command: "git remote get-url origin",
        exitCode: 128,
        stderr: "fatal: not a git repository",
        stdout: "",
      })),
      execJson: () => Effect.succeed({}) as any,
      execLines: () => Effect.succeed([]) as any,
    })
    const exit = await Effect.runPromiseExit(
      hasRemote("origin", GitCommonPath("/repo/.git")).pipe(Effect.provideService(ShellService, shell))
    )

    expect(Exit.isFailure(exit)).toBe(true)
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      expect(exit.cause.error._tag).toBe("GitNotRepoError")
    }
  })
})
