import { afterAll, beforeAll, describe, expect, it } from "bun:test"
import { mkdtempSync, rmSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"
import { Effect, Layer } from "effect"
import { BunContext } from "@effect/platform-bun"
import { ShellLive } from "../../Shell"
import { createTmpRepo, extractError, git, run, runExit } from "./setup.test"
import { ShellError } from "../../Shell/errors"
import {
  GitNotRepoError,
  GitRefDoesNotExistError,
  GitUnknownError
} from "../errors"
import { checkout } from "../public/checkout"
import { currentBranch } from "../public/current-branch"
import { isDirty } from "../public/is-dirty"
import { rebase } from "../public/rebase"
import { repoRoot } from "../public/repo-root"
import { worktreeAdd } from "../public/worktree-add"
import { worktreeList } from "../public/worktree-list"
import { worktreeRemove } from "../public/worktree-remove"
import { AbsolutePath, WorktreePath, BranchName, GitCommonPath } from "../types"

const FullLayer = ShellLive.pipe(Layer.provideMerge(BunContext.layer))

const _runFull = <A, E>(effect: Effect.Effect<A, E, any>): Promise<A> =>
  Effect.runPromise(effect.pipe(Effect.provide(FullLayer)) as Effect.Effect<A>)

let tmpDir: string
let notRepoDir: string

beforeAll(async () => {
  tmpDir = await createTmpRepo()
  notRepoDir = mkdtempSync(join(tmpdir(), "git-integ-notrepo-"))
})

afterAll(() => {
  rmSync(tmpDir, { recursive: true, force: true })
  rmSync(notRepoDir, { recursive: true, force: true })
})

describe("Git integration (error types)", () => {
  describe("Git operation errors", () => {
    it("repoRoot fails with GitNotRepoError and includes cause", async () => {
      const exit = await runExit(repoRoot(AbsolutePath(notRepoDir)))
      const error = extractError(exit) as GitNotRepoError
      expect(error).toBeInstanceOf(GitNotRepoError)
      expect(error.cause).toBeInstanceOf(ShellError)
      expect(error.cause!.stderr).toContain("not a git repository")
    })

    it("currentBranch fails with GitNotRepoError", async () => {
      const exit = await runExit(currentBranch(WorktreePath(notRepoDir)))
      const error = extractError(exit) as GitNotRepoError
      expect(error).toBeInstanceOf(GitNotRepoError)
      expect(error.cause).toBeInstanceOf(ShellError)
    })

    it("isDirty fails with GitNotRepoError", async () => {
      const exit = await runExit(isDirty(WorktreePath(notRepoDir)))
      const error = extractError(exit) as GitNotRepoError
      expect(error).toBeInstanceOf(GitNotRepoError)
    })

    it("worktreeList fails with GitNotRepoError", async () => {
      const FullExit = ShellLive.pipe(Layer.provideMerge(BunContext.layer))
      const exit = await Effect.runPromiseExit(worktreeList(GitCommonPath(notRepoDir)).pipe(Effect.provide(FullExit)))
      const error = extractError(exit) as GitNotRepoError
      expect(error).toBeInstanceOf(GitNotRepoError)
    })

    it("checkout fails with GitNotRepoError", async () => {
      const exit = await runExit(checkout(BranchName("main"), WorktreePath(notRepoDir)))
      const error = extractError(exit) as GitNotRepoError
      expect(error).toBeInstanceOf(GitNotRepoError)
    })

    it("worktreeAdd fails with GitNotRepoError", async () => {
      const FullExit = ShellLive.pipe(Layer.provideMerge(BunContext.layer))
      const exit = await Effect.runPromiseExit(worktreeAdd(BranchName("main"), GitCommonPath(notRepoDir), { path: "/tmp/doesnt-matter" }).pipe(Effect.provide(FullExit)))
      const error = extractError(exit) as GitNotRepoError
      expect(error).toBeInstanceOf(GitNotRepoError)
    })

    it("worktreeRemove fails with GitNotRepoError on non-repo path", async () => {
      const exit = await runExit(worktreeRemove(WorktreePath(notRepoDir)))
      const error = extractError(exit) as GitNotRepoError
      expect(error).toBeInstanceOf(GitNotRepoError)
    })

    it("rebase fails with GitNotRepoError", async () => {
      const exit = await runExit(rebase(BranchName("main"), WorktreePath(notRepoDir)))
      const error = extractError(exit) as GitNotRepoError
      expect(error).toBeInstanceOf(GitNotRepoError)
    })
  })

  describe("GitWorktreeAddError path conflict", () => {
    const wtBranch = "wt-exists-test"
    let wtPath: string

    beforeAll(() =>
      run(
        Effect.gen(function* () {
          wtPath = `${tmpDir}-wt-exists-${wtBranch}`
          yield* git(tmpDir, "branch", wtBranch)
          yield* git(tmpDir, "worktree", "add", wtPath, wtBranch)
        }),
      ),
    )

    afterAll(() =>
      run(
        Effect.gen(function* () {
          yield* git(tmpDir, "worktree", "remove", "--force", wtPath).pipe(Effect.ignore)
          yield* git(tmpDir, "branch", "-D", wtBranch).pipe(Effect.ignore)
        }),
      ),
    )

    it("worktreeAdd fails with GitUnknownError on path conflict", async () => {
      const gitDir = join(tmpDir, ".git")
      const FullExit = ShellLive.pipe(Layer.provideMerge(BunContext.layer))
      const exit = await Effect.runPromiseExit(worktreeAdd(BranchName(wtBranch), GitCommonPath(gitDir), { path: wtPath }).pipe(Effect.provide(FullExit)))
      const error = extractError(exit) as GitUnknownError
      expect(error).toBeInstanceOf(GitUnknownError)
      expect(error.cause).toBeInstanceOf(ShellError)
    })
  })

  describe("GitWorktreeAddError branch exists", () => {
    it("worktreeAdd with create fails when branch already exists", async () => {
      const branchName = "branch-exists-test"
      const wtPath = `${tmpDir}-wt-brexists-${branchName}`
      await run(git(tmpDir, "branch", branchName))

      const gitDir = join(tmpDir, ".git")
      const FullExit = ShellLive.pipe(Layer.provideMerge(BunContext.layer))
      const exit = await Effect.runPromiseExit(worktreeAdd(BranchName(branchName), GitCommonPath(gitDir), { path: wtPath, create: true }).pipe(Effect.provide(FullExit)))
      await run(git(tmpDir, "branch", "-D", branchName).pipe(Effect.ignore))

      const error = extractError(exit) as GitUnknownError
      expect(error).toBeInstanceOf(GitUnknownError)
      expect(error.cause).toBeInstanceOf(ShellError)
    })
  })

  describe("GitRebaseError cause chain", () => {
    it("includes ShellError cause with stderr", async () => {
      await run(
        Effect.gen(function* () {
          yield* git(tmpDir, "checkout", "main")
          writeFileSync(join(tmpDir, "cause-conflict.txt"), "main version")
          yield* git(tmpDir, "add", "cause-conflict.txt")
          yield* git(tmpDir, "commit", "-m", "main side for cause test")

          yield* git(tmpDir, "branch", "cause-conflict-test", "HEAD~1")
          yield* git(tmpDir, "checkout", "cause-conflict-test")
          writeFileSync(join(tmpDir, "cause-conflict.txt"), "branch version")
          yield* git(tmpDir, "add", "cause-conflict.txt")
          yield* git(tmpDir, "commit", "-m", "branch side for cause test")
        }),
      )

      const exit = await runExit(rebase(BranchName("main"), WorktreePath(tmpDir)))

      await run(
        Effect.gen(function* () {
          yield* git(tmpDir, "rebase", "--abort").pipe(Effect.ignore)
          yield* git(tmpDir, "checkout", "main").pipe(Effect.ignore)
          yield* git(tmpDir, "branch", "-D", "cause-conflict-test").pipe(Effect.ignore)
        }),
      )

      const error = extractError(exit) as GitUnknownError
      expect(error).toBeInstanceOf(GitUnknownError)
      expect(error.cause).toBeInstanceOf(ShellError)
      expect(error.cause!.exitCode).not.toBe(0)
    })
  })

  describe("Git operation errors with invalid refs", () => {
    it("checkout of non-existent branch returns GitRefDoesNotExistError", async () => {
      const exit = await runExit(checkout(BranchName("nonexistent-branch-xyz"), WorktreePath(tmpDir)))
      const error = extractError(exit) as GitRefDoesNotExistError
      expect(error).toBeInstanceOf(GitRefDoesNotExistError)
      expect(error.cause).toBeInstanceOf(ShellError)
    })

    it("worktreeAdd with non-existent branch returns GitRefDoesNotExistError", async () => {
      const wtPath = `${tmpDir}-wt-nonexistent`
      const gitDir = join(tmpDir, ".git")
      const FullExit = ShellLive.pipe(Layer.provideMerge(BunContext.layer))
      const exit = await Effect.runPromiseExit(worktreeAdd(BranchName("nonexistent-branch-xyz"), GitCommonPath(gitDir), { path: wtPath }).pipe(Effect.provide(FullExit)))
      const error = extractError(exit) as GitRefDoesNotExistError
      expect(error).toBeInstanceOf(GitRefDoesNotExistError)
      expect(error.cause).toBeInstanceOf(ShellError)
    })
  })
})
