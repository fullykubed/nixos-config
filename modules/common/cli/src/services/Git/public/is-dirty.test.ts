import { describe, it, expect } from "bun:test"
import { Effect, Exit } from "effect"
import { isDirty } from "./is-dirty"
import { ShellService, ShellError } from "../../Shell"
import { WorktreePath } from "../types"

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

describe("isDirty", () => {
  it("should return false when repo is clean", async () => {
    const shell = createMockShell("")
    const result = await Effect.runPromise(
      isDirty(WorktreePath("/some/path")).pipe(Effect.provideService(ShellService, shell))
    )
    expect(result).toBe(false)
  })

  it("should return true when repo has uncommitted changes", async () => {
    const shell = createMockShell(" M src/file.ts\n A new-file.ts\n")
    const result = await Effect.runPromise(
      isDirty(WorktreePath("/some/path")).pipe(Effect.provideService(ShellService, shell))
    )
    expect(result).toBe(true)
  })

  it("should return true when repo has single change", async () => {
    const shell = createMockShell("M  src/file.ts")
    const result = await Effect.runPromise(
      isDirty(WorktreePath("/some/path")).pipe(Effect.provideService(ShellService, shell))
    )
    expect(result).toBe(true)
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
      isDirty(WorktreePath("/some/path")).pipe(Effect.provideService(ShellService, shell))
    )

    expect(capturedOpts).toEqual({ cwd: "/some/path" })
  })

  it("should fail with GitNotRepoError when not a git repo", async () => {
    const shell = createMockShell("", true)
    const exit = await Effect.runPromiseExit(
      isDirty(WorktreePath("/some/path")).pipe(Effect.provideService(ShellService, shell))
    )

    expect(Exit.isFailure(exit)).toBe(true)
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      expect(exit.cause.error._tag).toBe("GitNotRepoError")
    }
  })

  it("should fail with GitUnknownError on other shell errors", async () => {
    const shell = {
      exec: () => Effect.fail(new ShellError({
        command: "git status --porcelain",
        exitCode: 1,
        stderr: "fatal: some unexpected error",
        stdout: "",
      })),
      execJson: <T>() => Effect.succeed({} as T),
      execLines: () => Effect.succeed([]),
    }

    const exit = await Effect.runPromiseExit(
      isDirty(WorktreePath("/some/path")).pipe(Effect.provideService(ShellService, shell))
    )

    expect(Exit.isFailure(exit)).toBe(true)
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      expect(exit.cause.error._tag).toBe("GitUnknownError")
    }
  })
})