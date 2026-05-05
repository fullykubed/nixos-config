import { afterAll, beforeAll, describe, expect, it } from "bun:test"
import { rmSync, writeFileSync } from "node:fs"
import { join } from "node:path"
import { Effect, Exit } from "effect"
import { createTmpRepo, git, run, runExit } from "./setup.test"
import { GitUnknownError } from "../errors"
import { checkout } from "../public/checkout"
import { currentBranch } from "../public/current-branch"
import { merge } from "../public/merge"
import { mergeSquash } from "../public/merge-squash"
import { commit } from "../public/commit"
import { rebase } from "../public/rebase"
import { BranchName, WorktreePath } from "../types"

let tmpDir: string

beforeAll(async () => {
  tmpDir = await createTmpRepo()
})

afterAll(() => {
  rmSync(tmpDir, { recursive: true, force: true })
})

describe.serial("Git integration (merge & rebase)", () => {
  describe.serial("checkout", () => {
    const branchName = "checkout-test"

    afterAll(() =>
      run(
        Effect.gen(function* () {
          yield* git(tmpDir, "checkout", "main").pipe(Effect.ignore)
          yield* git(tmpDir, "branch", "-D", branchName).pipe(Effect.ignore)
        }),
      ),
    )

    it("switches to a new branch", () =>
      run(
        Effect.gen(function* () {
          yield* git(tmpDir, "branch", branchName)
          yield* checkout(BranchName(branchName), WorktreePath(tmpDir))
          const branch = yield* currentBranch(WorktreePath(tmpDir))
          expect(String(branch)).toBe(branchName)
          yield* checkout(BranchName("main"), WorktreePath(tmpDir))
        }),
      ))
  })

  describe.serial("rebase", () => {
    it("rebases a branch onto main", () =>
      run(
        Effect.gen(function* () {
          const branch = "rebase-test"
          yield* git(tmpDir, "checkout", "main")
          writeFileSync(join(tmpDir, "main-file.txt"), "main content")
          yield* git(tmpDir, "add", "main-file.txt")
          yield* git(tmpDir, "commit", "-m", "main commit for rebase")

          yield* git(tmpDir, "branch", branch, "HEAD~1")
          yield* git(tmpDir, "checkout", branch)
          writeFileSync(join(tmpDir, "branch-file.txt"), "branch content")
          yield* git(tmpDir, "add", "branch-file.txt")
          yield* git(tmpDir, "commit", "-m", "branch commit for rebase")

          yield* rebase(BranchName("main"), WorktreePath(tmpDir))

          const log = yield* git(tmpDir, "log", "--oneline")
          expect(log).toContain("branch commit for rebase")
          expect(log).toContain("main commit for rebase")

          yield* git(tmpDir, "checkout", "main")
          yield* git(tmpDir, "branch", "-D", branch)
        }),
      ))

    it("fails with GitUnknownError on conflict", async () => {
      await run(
        Effect.gen(function* () {
          yield* git(tmpDir, "checkout", "main")
          writeFileSync(join(tmpDir, "conflict.txt"), "main version")
          yield* git(tmpDir, "add", "conflict.txt")
          yield* git(tmpDir, "commit", "-m", "main side of conflict")

          yield* git(tmpDir, "branch", "rebase-conflict-test", "HEAD~1")
          yield* git(tmpDir, "checkout", "rebase-conflict-test")
          writeFileSync(join(tmpDir, "conflict.txt"), "branch version")
          yield* git(tmpDir, "add", "conflict.txt")
          yield* git(tmpDir, "commit", "-m", "branch side of conflict")
        }),
      )

      const exit = await runExit(rebase(BranchName("main"), WorktreePath(tmpDir)))

      // Always clean up before asserting (prevents cascading failures)
      await run(
        Effect.gen(function* () {
          yield* git(tmpDir, "rebase", "--abort").pipe(Effect.ignore)
          yield* git(tmpDir, "checkout", "main").pipe(Effect.ignore)
          yield* git(tmpDir, "branch", "-D", "rebase-conflict-test").pipe(Effect.ignore)
        }),
      )

      expect(Exit.isFailure(exit)).toBe(true)
      if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
        expect(exit.cause.error._tag).toBe("GitUnknownError")
        expect(exit.cause.error).toBeInstanceOf(GitUnknownError)
      }
    })
  })

  describe.serial("merge", () => {
    it("merges a branch into main", () =>
      run(
        Effect.gen(function* () {
          const branch = "merge-test"
          yield* git(tmpDir, "checkout", "-b", branch)
          writeFileSync(join(tmpDir, "merge-file.txt"), "merge content")
          yield* git(tmpDir, "add", "merge-file.txt")
          yield* git(tmpDir, "commit", "-m", "commit to merge")

          yield* git(tmpDir, "checkout", "main")
          yield* merge(BranchName(branch), WorktreePath(tmpDir))

          const log = yield* git(tmpDir, "log", "--oneline")
          expect(log).toContain("commit to merge")

          yield* git(tmpDir, "branch", "-D", branch)
        }),
      ))
  })

  describe.serial("mergeSquash + commit", () => {
    it("squash-merges a multi-commit branch", () =>
      run(
        Effect.gen(function* () {
          const branch = "squash-test"
          yield* git(tmpDir, "checkout", "-b", branch)
          writeFileSync(join(tmpDir, "squash-a.txt"), "a")
          yield* git(tmpDir, "add", "squash-a.txt")
          yield* git(tmpDir, "commit", "-m", "squash commit 1")
          writeFileSync(join(tmpDir, "squash-b.txt"), "b")
          yield* git(tmpDir, "add", "squash-b.txt")
          yield* git(tmpDir, "commit", "-m", "squash commit 2")

          yield* git(tmpDir, "checkout", "main")
          yield* mergeSquash(BranchName(branch), WorktreePath(tmpDir))
          yield* commit(WorktreePath(tmpDir), "squashed feature")

          const log = yield* git(tmpDir, "log", "--oneline", "-1")
          expect(log).toContain("squashed feature")

          yield* git(tmpDir, "branch", "-D", branch)
        }),
      ))
  })
})
