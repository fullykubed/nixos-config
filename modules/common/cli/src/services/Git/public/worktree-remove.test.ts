import { describe, it, expect } from "bun:test"
import { Effect, Exit } from "effect"
import { worktreeRemove } from "./worktree-remove"
import { WorktreePath } from "../types"
import { ShellService, ShellError } from "../../Shell"

describe("worktreeRemove", () => {
  it("should execute git worktree remove command", async () => {
    let capturedArgs: string[] = []
    const shell = ShellService.of({
      exec: (cmd, args, _opts) => {
        capturedArgs = [cmd, ...args]
        return Effect.succeed({ stdout: "", stderr: "", exitCode: 0 })
      },
      execJson: () => Effect.succeed({}) as any,
      execLines: () => Effect.succeed([]) as any,
    })

    await Effect.runPromise(
      worktreeRemove(WorktreePath("/path/to/worktree")).pipe(Effect.provideService(ShellService, shell))
    )

    expect(capturedArgs).toEqual(["git", "worktree", "remove", "/path/to/worktree"])
  })

  it("should add --force flag when force option is true", async () => {
    let capturedArgs: string[] = []
    const shell = ShellService.of({
      exec: (cmd, args, _opts) => {
        capturedArgs = [cmd, ...args]
        return Effect.succeed({ stdout: "", stderr: "", exitCode: 0 })
      },
      execJson: () => Effect.succeed({}) as any,
      execLines: () => Effect.succeed([]) as any,
    })

    await Effect.runPromise(
      worktreeRemove(WorktreePath("/path/to/worktree"), { force: true }).pipe(Effect.provideService(ShellService, shell))
    )

    expect(capturedArgs).toEqual(["git", "worktree", "remove", "/path/to/worktree", "--force"])
  })

  it("should not add --force flag when force option is false", async () => {
    let capturedArgs: string[] = []
    const shell = ShellService.of({
      exec: (cmd, args, _opts) => {
        capturedArgs = [cmd, ...args]
        return Effect.succeed({ stdout: "", stderr: "", exitCode: 0 })
      },
      execJson: () => Effect.succeed({}) as any,
      execLines: () => Effect.succeed([]) as any,
    })

    await Effect.runPromise(
      worktreeRemove(WorktreePath("/path/to/worktree"), { force: false }).pipe(Effect.provideService(ShellService, shell))
    )

    expect(capturedArgs).toEqual(["git", "worktree", "remove", "/path/to/worktree"])
  })

  it("should use the worktree path as cwd", async () => {
    let capturedOpts: any = undefined
    const shell = ShellService.of({
      exec: (cmd, args, opts) => {
        capturedOpts = opts
        return Effect.succeed({ stdout: "", stderr: "", exitCode: 0 })
      },
      execJson: () => Effect.succeed({}) as any,
      execLines: () => Effect.succeed([]) as any,
    })

    await Effect.runPromise(
      worktreeRemove(WorktreePath("/path/to/worktree")).pipe(Effect.provideService(ShellService, shell))
    )

    expect(capturedOpts).toEqual({ cwd: "/path/to/worktree" })
  })

  it("should fail with GitNotRepoError when not a git repo", async () => {
    const shell = ShellService.of({
      exec: () => Effect.fail(new ShellError({
        command: "git worktree remove",
        exitCode: 128,
        stderr: "fatal: not a git repository (or any of the parent directories): .git",
        stdout: "",
      })),
      execJson: () => Effect.succeed({}) as any,
      execLines: () => Effect.succeed([]) as any,
    })

    const exit = await Effect.runPromiseExit(
      worktreeRemove(WorktreePath("/path/to/worktree")).pipe(Effect.provideService(ShellService, shell))
    )

    expect(Exit.isFailure(exit)).toBe(true)
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      expect(exit.cause.error._tag).toBe("GitNotRepoError")
    }
  })

  it("should fail with GitUnknownError on modified or untracked files", async () => {
    const shell = ShellService.of({
      exec: () => Effect.fail(new ShellError({
        command: "git worktree remove",
        exitCode: 128,
        stderr: "fatal: '/path/to/worktree' contains modified or untracked files, use --force to delete them",
        stdout: "",
      })),
      execJson: () => Effect.succeed({}) as any,
      execLines: () => Effect.succeed([]) as any,
    })

    const exit = await Effect.runPromiseExit(
      worktreeRemove(WorktreePath("/path/to/worktree")).pipe(Effect.provideService(ShellService, shell))
    )

    expect(Exit.isFailure(exit)).toBe(true)
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      expect(exit.cause.error._tag).toBe("GitUnknownError")
    }
  })

  it("should fail with GitUnknownError on other shell errors", async () => {
    const shell = ShellService.of({
      exec: () => Effect.fail(new ShellError({
        command: "git worktree remove",
        exitCode: 1,
        stderr: "fatal: some unexpected error",
        stdout: "",
      })),
      execJson: () => Effect.succeed({}) as any,
      execLines: () => Effect.succeed([]) as any,
    })

    const exit = await Effect.runPromiseExit(
      worktreeRemove(WorktreePath("/path/to/worktree")).pipe(Effect.provideService(ShellService, shell))
    )

    expect(Exit.isFailure(exit)).toBe(true)
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      expect(exit.cause.error._tag).toBe("GitUnknownError")
    }
  })
})