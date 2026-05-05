import { describe, it, expect } from "bun:test"
import { Effect, Exit } from "effect"
import { pull } from "./pull"
import { ShellService, ShellError } from "../../Shell"
import { WorktreePath } from "../types"

describe("pull", () => {
  it("should default to --rebase", async () => {
    let capturedArgs: string[] = []
    const shell = {
      exec: (cmd: string, args: readonly string[], _opts?: any) => {
        capturedArgs = [cmd, ...args]
        return Effect.succeed({ stdout: "", stderr: "", exitCode: 0 })
      },
      execJson: <T>() => Effect.succeed({} as T),
      execLines: () => Effect.succeed([]),
    }

    await Effect.runPromise(
      pull(WorktreePath("/some/path")).pipe(Effect.provideService(ShellService, shell))
    )

    expect(capturedArgs).toEqual(["git", "pull", "--rebase"])
  })

  it("should add --rebase flag when rebase option is true", async () => {
    let capturedArgs: string[] = []
    const shell = {
      exec: (cmd: string, args: readonly string[], _opts?: any) => {
        capturedArgs = [cmd, ...args]
        return Effect.succeed({ stdout: "", stderr: "", exitCode: 0 })
      },
      execJson: <T>() => Effect.succeed({} as T),
      execLines: () => Effect.succeed([]),
    }

    await Effect.runPromise(
      pull(WorktreePath("/some/path"), { rebase: true }).pipe(Effect.provideService(ShellService, shell))
    )

    expect(capturedArgs).toEqual(["git", "pull", "--rebase"])
  })

  it("should not add --rebase flag when rebase option is explicitly false", async () => {
    let capturedArgs: string[] = []
    const shell = {
      exec: (cmd: string, args: readonly string[], _opts?: any) => {
        capturedArgs = [cmd, ...args]
        return Effect.succeed({ stdout: "", stderr: "", exitCode: 0 })
      },
      execJson: <T>() => Effect.succeed({} as T),
      execLines: () => Effect.succeed([]),
    }

    await Effect.runPromise(
      pull(WorktreePath("/some/path"), { rebase: false }).pipe(Effect.provideService(ShellService, shell))
    )

    expect(capturedArgs).toEqual(["git", "pull"])
  })

  it("should pass cwd option to shell", async () => {
    let capturedOpts: any = undefined
    const shell = {
      exec: (cmd: string, args: readonly string[], opts?: any) => {
        capturedOpts = opts
        return Effect.succeed({ stdout: "", stderr: "", exitCode: 0 })
      },
      execJson: <T>() => Effect.succeed({} as T),
      execLines: () => Effect.succeed([]),
    }

    await Effect.runPromise(
      pull(WorktreePath("/some/cwd")).pipe(Effect.provideService(ShellService, shell))
    )

    expect(capturedOpts).toEqual({ cwd: "/some/cwd" })
  })

  it("should fail with GitNotRepoError when not a git repo", async () => {
    const shell = ShellService.of({
      exec: () => Effect.fail(new ShellError({
        command: "git pull",
        exitCode: 128,
        stderr: "fatal: not a git repository (or any of the parent directories): .git",
        stdout: "",
      })),
      execJson: <T>() => Effect.succeed({} as T),
      execLines: () => Effect.succeed([]),
    })

    const exit = await Effect.runPromiseExit(
      pull(WorktreePath("/some/path")).pipe(Effect.provideService(ShellService, shell))
    )

    expect(Exit.isFailure(exit)).toBe(true)
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      expect(exit.cause.error._tag).toBe("GitNotRepoError")
    }
  })

  it("should fail with GitConnectivityError on network failure", async () => {
    const shell = ShellService.of({
      exec: () => Effect.fail(new ShellError({
        command: "git pull",
        exitCode: 1,
        stderr: "fatal: unable to access 'https://github.com/repo.git/': Could not resolve host: github.com",
        stdout: "",
      })),
      execJson: <T>() => Effect.succeed({} as T),
      execLines: () => Effect.succeed([]),
    })

    const exit = await Effect.runPromiseExit(
      pull(WorktreePath("/some/path")).pipe(Effect.provideService(ShellService, shell))
    )

    expect(Exit.isFailure(exit)).toBe(true)
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      expect(exit.cause.error._tag).toBe("GitConnectivityError")
    }
  })

  it("should fail with GitError on other shell errors", async () => {
    const shell = ShellService.of({
      exec: () => Effect.fail(new ShellError({
        command: "git pull",
        exitCode: 1,
        stderr: "fatal: some unexpected error",
        stdout: "",
      })),
      execJson: <T>() => Effect.succeed({} as T),
      execLines: () => Effect.succeed([]),
    })

    const exit = await Effect.runPromiseExit(
      pull(WorktreePath("/some/path")).pipe(Effect.provideService(ShellService, shell))
    )

    expect(Exit.isFailure(exit)).toBe(true)
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      expect(exit.cause.error._tag).toBe("GitUnknownError")
    }
  })
})
