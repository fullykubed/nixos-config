import { describe, it, expect } from "bun:test"
import { Effect, Exit } from "effect"
import { rebase } from "./rebase"
import { ShellService, ShellError } from "../../Shell"
import { BranchName, WorktreePath } from "../types"

describe("rebase", () => {
  it("should execute git rebase command", async () => {
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
      rebase(BranchName("main"), WorktreePath("/some/path")).pipe(Effect.provideService(ShellService, shell))
    )

    expect(capturedArgs).toEqual(["git", "rebase", "main"])
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
      rebase(BranchName("main"), WorktreePath("/some/cwd")).pipe(Effect.provideService(ShellService, shell))
    )

    expect(capturedOpts).toEqual({ cwd: "/some/cwd" })
  })

  it("should fail with GitUnknownError on conflict", async () => {
    const shell = ShellService.of({
      exec: () => Effect.fail(new ShellError({
        command: "git rebase",
        exitCode: 1,
        stderr: "CONFLICT (content): Merge conflict in src/file.ts",
        stdout: "",
      })),
      execJson: <T>() => Effect.succeed({} as T),
      execLines: () => Effect.succeed([]),
    })

    const exit = await Effect.runPromiseExit(
      rebase(BranchName("main"), WorktreePath("/some/path")).pipe(Effect.provideService(ShellService, shell))
    )

    expect(Exit.isFailure(exit)).toBe(true)
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      expect(exit.cause.error._tag).toBe("GitUnknownError")
    }
  })

  it("should fail with GitUnknownError on exit code 1", async () => {
    const shell = ShellService.of({
      exec: () => Effect.fail(new ShellError({
        command: "git rebase",
        exitCode: 1,
        stderr: "Some rebase error without conflict keyword",
        stdout: "",
      })),
      execJson: <T>() => Effect.succeed({} as T),
      execLines: () => Effect.succeed([]),
    })

    const exit = await Effect.runPromiseExit(
      rebase(BranchName("main"), WorktreePath("/some/path")).pipe(Effect.provideService(ShellService, shell))
    )

    expect(Exit.isFailure(exit)).toBe(true)
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      expect(exit.cause.error._tag).toBe("GitUnknownError")
    }
  })

  it("should fail with GitNotRepoError when not a git repo", async () => {
    const shell = ShellService.of({
      exec: () => Effect.fail(new ShellError({
        command: "git rebase",
        exitCode: 128,
        stderr: "fatal: not a git repository",
        stdout: "",
      })),
      execJson: <T>() => Effect.succeed({} as T),
      execLines: () => Effect.succeed([]),
    })

    const exit = await Effect.runPromiseExit(
      rebase(BranchName("main"), WorktreePath("/some/path")).pipe(Effect.provideService(ShellService, shell))
    )

    expect(Exit.isFailure(exit)).toBe(true)
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      expect(exit.cause.error._tag).toBe("GitNotRepoError")
    }
  })

  it("should fail with GitError on other shell errors", async () => {
    const shell = ShellService.of({
      exec: () => Effect.fail(new ShellError({
        command: "git rebase",
        exitCode: 128,
        stderr: "fatal: some unexpected error",
        stdout: "",
      })),
      execJson: <T>() => Effect.succeed({} as T),
      execLines: () => Effect.succeed([]),
    })

    const exit = await Effect.runPromiseExit(
      rebase(BranchName("main"), WorktreePath("/some/path")).pipe(Effect.provideService(ShellService, shell))
    )

    expect(Exit.isFailure(exit)).toBe(true)
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      expect(exit.cause.error._tag).toBe("GitUnknownError")
    }
  })
})