import { describe, it, expect } from "bun:test"
import { Effect, Exit } from "effect"
import { currentBranch } from "./current-branch"
import { ShellService, ShellError } from "../../Shell"
import { WorktreePath, BranchName } from "../types"

const createMockShell = (stdout: string, shouldFail = false) => ({
  exec: (cmd: string, args: readonly string[], _opts?: any) => {
    if (shouldFail) {
      return Effect.fail(new ShellError({
        command: `${cmd} ${args.join(" ")}`,
        exitCode: 1,
        stderr: "fatal: not a git repository",
        stdout: "",
      }))
    }
    return Effect.succeed({ stdout, stderr: "", exitCode: 0 })
  },
  execJson: <T>() => Effect.succeed({} as T),
  execLines: () => Effect.succeed([]),
})

describe("currentBranch", () => {
  it("should return current branch name", async () => {
    const shell = createMockShell("feature/test-branch\n")
    const result = await Effect.runPromise(
      currentBranch(WorktreePath("/some/path")).pipe(Effect.provideService(ShellService, shell))
    )
    expect(result).toBe(BranchName("feature/test-branch"))
  })

  it("should handle HEAD branch", async () => {
    const shell = createMockShell("HEAD")
    const result = await Effect.runPromise(
      currentBranch(WorktreePath("/some/path")).pipe(Effect.provideService(ShellService, shell))
    )
    expect(result).toBe(BranchName("HEAD"))
  })

  it("should pass cwd option to shell", async () => {
    let capturedOpts: any = undefined
    const shell = {
      exec: (cmd: string, args: readonly string[], opts?: any) => {
        capturedOpts = opts
        return Effect.succeed({ stdout: "main", stderr: "", exitCode: 0 })
      },
      execJson: <T>() => Effect.succeed({} as T),
      execLines: () => Effect.succeed([]),
    }

    await Effect.runPromise(
      currentBranch(WorktreePath("/some/path")).pipe(Effect.provideService(ShellService, shell))
    )

    expect(capturedOpts).toEqual({ cwd: "/some/path" })
  })

  it("should fail with GitNotRepoError when not a git repo", async () => {
    const shell = createMockShell("", true)
    const exit = await Effect.runPromiseExit(
      currentBranch(WorktreePath("/some/path")).pipe(Effect.provideService(ShellService, shell))
    )

    expect(Exit.isFailure(exit)).toBe(true)
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      expect(exit.cause.error._tag).toBe("GitNotRepoError")
    }
  })

  it("should fail with GitUnknownError on other shell errors", async () => {
    const shell = {
      exec: () => Effect.fail(new ShellError({
        command: "git rev-parse --abbrev-ref HEAD",
        exitCode: 1,
        stderr: "fatal: some unexpected error",
        stdout: "",
      })),
      execJson: <T>() => Effect.succeed({} as T),
      execLines: () => Effect.succeed([]),
    }

    const exit = await Effect.runPromiseExit(
      currentBranch(WorktreePath("/some/path")).pipe(Effect.provideService(ShellService, shell))
    )

    expect(Exit.isFailure(exit)).toBe(true)
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      expect(exit.cause.error._tag).toBe("GitUnknownError")
    }
  })
})