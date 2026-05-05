import { describe, it, expect } from "bun:test"
import { Effect, Exit, Context } from "effect"
import { Path } from "@effect/platform"
import { worktreeAdd } from "./worktree-add"
import { BranchName, GitCommonPath, WorktreePath } from "../types"
import { ShellService, ShellError } from "../../Shell"

const mockPath = Path.Path.of({
  resolve: (...paths: string[]) => paths.join("/")
} as never)

const provideServices = (shell: any) =>
  Effect.provide(Context.empty().pipe(
    Context.add(ShellService, shell),
    Context.add(Path.Path, mockPath)
  ))

describe("worktreeAdd", () => {
  it("should execute git worktree add command with explicit path", async () => {
    let capturedArgs: string[] = []
    const shell = ShellService.of({
      exec: (cmd, args) => {
        capturedArgs = [cmd, ...args]
        return Effect.succeed({ stdout: "", stderr: "", exitCode: 0 })
      },
      execJson: () => Effect.succeed({}) as any,
      execLines: () => Effect.succeed([]) as any,
    })

    const result = await Effect.runPromise(
      worktreeAdd(BranchName("feature-branch"), GitCommonPath("/repo/.git"), { path: "/path/to/worktree" }).pipe(provideServices(shell))
    )

    expect(capturedArgs).toEqual(["git", "worktree", "add", "/path/to/worktree", "feature-branch"])
    expect(result).toBe(WorktreePath("/path/to/worktree"))
  })

  it("should pass cwd option to shell", async () => {
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
      worktreeAdd(BranchName("feature-branch"), GitCommonPath("/some/cwd"), { path: "/path/to/worktree" }).pipe(provideServices(shell))
    )

    expect(capturedOpts).toEqual({ cwd: "/some/cwd" })
  })

  it("should use -b flag when create option is true", async () => {
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
      worktreeAdd(BranchName("new-branch"), GitCommonPath("/repo/.git"), { path: "/path/to/worktree", create: true }).pipe(provideServices(shell))
    )

    expect(capturedArgs).toEqual(["git", "worktree", "add", "-b", "new-branch", "/path/to/worktree"])
  })

  it("returns the worktree path", async () => {
    const shell = ShellService.of({
      exec: () => Effect.succeed({ stdout: "", stderr: "", exitCode: 0 }),
      execJson: () => Effect.succeed({}) as any,
      execLines: () => Effect.succeed([]) as any,
    })

    const result = await Effect.runPromise(
      worktreeAdd(BranchName("feature-branch"), GitCommonPath("/repo/.git"), { path: "/custom/path" }).pipe(provideServices(shell))
    )

    expect(result).toBe(WorktreePath("/custom/path"))
  })

  it("should fail with GitNotRepoError when not a git repo", async () => {
    const shell = ShellService.of({
      exec: () => Effect.fail(new ShellError({
        command: "git worktree add",
        exitCode: 128,
        stderr: "fatal: not a git repository (or any of the parent directories): .git",
        stdout: "",
      })),
      execJson: () => Effect.succeed({}) as any,
      execLines: () => Effect.succeed([]) as any,
    })

    const exit = await Effect.runPromiseExit(
      worktreeAdd(BranchName("feature-branch"), GitCommonPath("/repo/.git"), { path: "/path/to/worktree" }).pipe(provideServices(shell))
    )

    expect(Exit.isFailure(exit)).toBe(true)
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      expect(exit.cause.error._tag).toBe("GitNotRepoError")
    }
  })

  it("should fail with GitUnknownError when path already exists", async () => {
    const shell = ShellService.of({
      exec: () => Effect.fail(new ShellError({
        command: "git worktree add",
        exitCode: 128,
        stderr: "fatal: '/path/to/worktree' already exists",
        stdout: "",
      })),
      execJson: () => Effect.succeed({}) as any,
      execLines: () => Effect.succeed([]) as any,
    })

    const exit = await Effect.runPromiseExit(
      worktreeAdd(BranchName("feature-branch"), GitCommonPath("/repo/.git"), { path: "/path/to/worktree" }).pipe(provideServices(shell))
    )

    expect(Exit.isFailure(exit)).toBe(true)
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      expect(exit.cause.error._tag).toBe("GitUnknownError")
    }
  })

  it("should fail with GitRefDoesNotExistError when branch does not exist", async () => {
    const shell = ShellService.of({
      exec: () => Effect.fail(new ShellError({
        command: "git worktree add",
        exitCode: 128,
        stderr: "fatal: invalid reference: nonexistent-branch",
        stdout: "",
      })),
      execJson: () => Effect.succeed({}) as any,
      execLines: () => Effect.succeed([]) as any,
    })

    const exit = await Effect.runPromiseExit(
      worktreeAdd(BranchName("nonexistent-branch"), GitCommonPath("/repo/.git"), { path: "/path/to/worktree" }).pipe(provideServices(shell))
    )

    expect(Exit.isFailure(exit)).toBe(true)
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      expect(exit.cause.error._tag).toBe("GitRefDoesNotExistError")
    }
  })

  it("should fail with GitUnknownError when branch already exists with create", async () => {
    const shell = ShellService.of({
      exec: () => Effect.fail(new ShellError({
        command: "git worktree add",
        exitCode: 128,
        stderr: "fatal: a branch named 'feature-branch' already exists",
        stdout: "",
      })),
      execJson: () => Effect.succeed({}) as any,
      execLines: () => Effect.succeed([]) as any,
    })

    const exit = await Effect.runPromiseExit(
      worktreeAdd(BranchName("feature-branch"), GitCommonPath("/repo/.git"), { path: "/path/to/worktree", create: true }).pipe(provideServices(shell))
    )

    expect(Exit.isFailure(exit)).toBe(true)
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      expect(exit.cause.error._tag).toBe("GitUnknownError")
    }
  })

  it("should fail with GitUnknownError on other shell errors", async () => {
    const shell = ShellService.of({
      exec: () => Effect.fail(new ShellError({
        command: "git worktree add",
        exitCode: 1,
        stderr: "fatal: 'feature-branch' is already checked out",
        stdout: "",
      })),
      execJson: () => Effect.succeed({}) as any,
      execLines: () => Effect.succeed([]) as any,
    })

    const exit = await Effect.runPromiseExit(
      worktreeAdd(BranchName("feature-branch"), GitCommonPath("/repo/.git"), { path: "/path/to/worktree" }).pipe(provideServices(shell))
    )

    expect(Exit.isFailure(exit)).toBe(true)
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      expect(exit.cause.error._tag).toBe("GitUnknownError")
    }
  })
})
