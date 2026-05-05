import { afterAll, beforeAll, describe, expect, it } from "bun:test"
import { writeFileSync } from "node:fs"
import { rmSync } from "node:fs"
import { join } from "node:path"
import { Effect, Exit, Option, Layer } from "effect"
import { BunContext } from "@effect/platform-bun"
import { ShellLive } from "../../Shell"
import { createTmpRepo, git, run, runExit } from "./setup"
import { GitUnknownError } from "../errors"
import { isWorktree } from "../public/is-worktree"
import { worktreeAdd } from "../public/worktree-add"
import { worktreeList } from "../public/worktree-list"
import { worktreeRemove } from "../public/worktree-remove"
import { AbsolutePath, WorktreePath, BranchName, GitCommonPath } from "../types"

const FullLayer = ShellLive.pipe(Layer.provideMerge(BunContext.layer))

const runFull = <A, E>(effect: Effect.Effect<A, E, any>): Promise<A> =>
  Effect.runPromise(effect.pipe(Effect.provide(FullLayer)) as Effect.Effect<A>)

let tmpDir: string

beforeAll(async () => {
  tmpDir = await createTmpRepo()
})

afterAll(() => {
  rmSync(tmpDir, { recursive: true, force: true })
})

describe("Git integration (worktree lifecycle)", () => {
  describe("worktreeAdd + query", () => {
    const wtBranch = "wt-add-test"
    let wtPath: string

    beforeAll(() =>
      runFull(
        Effect.gen(function* () {
          wtPath = `${tmpDir}-wt-${wtBranch}`
          yield* git(tmpDir, "branch", wtBranch)
          const gitDir = join(tmpDir, ".git")
          yield* worktreeAdd(BranchName(wtBranch), GitCommonPath(gitDir), { path: wtPath })
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

    it("worktreeAdd creates a worktree visible in worktreeList", () =>
      runFull(
        Effect.gen(function* () {
          const gitDir = join(tmpDir, ".git")
          const list = yield* worktreeList(GitCommonPath(gitDir))
          const wt = list.find((w) => String(w.branch) === wtBranch)
          expect(wt).toBeDefined()
          expect(String(wt!.path)).toBe(wtPath)
          expect(String(wt!.branch)).toBe(wtBranch)
        }),
      ))

    it("isWorktree returns true from inside the worktree", () =>
      runFull(
        Effect.gen(function* () {
          const result = yield* isWorktree(AbsolutePath(wtPath))
          expect(Option.isSome(result)).toBe(true)
        }),
      ))
  })

  describe("worktreeRemove rejects dirty worktree", () => {
    const wtBranch = "wt-dirty-reject"
    let wtPath: string

    beforeAll(() =>
      runFull(
        Effect.gen(function* () {
          wtPath = `${tmpDir}-wt-${wtBranch}`
          yield* git(tmpDir, "branch", wtBranch)
          const gitDir = join(tmpDir, ".git")
          yield* worktreeAdd(BranchName(wtBranch), GitCommonPath(gitDir), { path: wtPath })
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

    it("fails with GitUnknownError", async () => {
      writeFileSync(join(wtPath, "dirty.txt"), "uncommitted")
      const exit = await runExit(worktreeRemove(WorktreePath(wtPath)))
      expect(Exit.isFailure(exit)).toBe(true)
      if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
        expect(exit.cause.error).toBeInstanceOf(GitUnknownError)
      }
    })
  })

  describe("worktreeRemove with force", () => {
    const wtBranch = "wt-dirty-force"
    let wtPath: string

    beforeAll(() =>
      runFull(
        Effect.gen(function* () {
          wtPath = `${tmpDir}-wt-${wtBranch}`
          yield* git(tmpDir, "branch", wtBranch)
          const gitDir = join(tmpDir, ".git")
          yield* worktreeAdd(BranchName(wtBranch), GitCommonPath(gitDir), { path: wtPath })
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

    it("removes dirty worktree", () =>
      runFull(
        Effect.gen(function* () {
          writeFileSync(join(wtPath, "dirty.txt"), "uncommitted")
          yield* worktreeRemove(WorktreePath(wtPath), { force: true })
          const gitDir = join(tmpDir, ".git")
          const list = yield* worktreeList(GitCommonPath(gitDir))
          const wt = list.find((w) => String(w.branch) === wtBranch)
          expect(wt).toBeUndefined()
        }),
      ))
  })

  describe("worktreeRemove rejects primary worktree", () => {
    it("fails with GitUnknownError", async () => {
      const exit = await runExit(worktreeRemove(WorktreePath(tmpDir)))
      expect(Exit.isFailure(exit)).toBe(true)
      if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
        expect(exit.cause.error).toBeInstanceOf(GitUnknownError)
      }
    })
  })
})
