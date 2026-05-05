import { afterAll, beforeAll, describe, expect, it } from "bun:test"
import { rmSync } from "node:fs"
import { Effect, Exit, Option, Layer } from "effect"
import { BunContext } from "@effect/platform-bun"
import { ShellLive } from "../../Shell"
import { createBareRepo, git, run, runExit } from "./setup"
import { currentBranch } from "../public/current-branch"
import { isDirty } from "../public/is-dirty"
import { isWorktree } from "../public/is-worktree"
import { repoRoot } from "../public/repo-root"
import { worktreeAdd } from "../public/worktree-add"
import { worktreeList } from "../public/worktree-list"
import { worktreeRemove } from "../public/worktree-remove"
import { AbsolutePath, WorktreePath, BranchName, GitCommonPath } from "../types"

const FullLayer = ShellLive.pipe(Layer.provideMerge(BunContext.layer))

const runFull = <A, E>(effect: Effect.Effect<A, E, any>): Promise<A> =>
  Effect.runPromise(effect.pipe(Effect.provide(FullLayer)) as Effect.Effect<A>)

let srcDir: string
let bareDir: string

beforeAll(async () => {
  const repos = await createBareRepo()
  srcDir = repos.srcDir
  bareDir = repos.bareDir
})

afterAll(() => {
  rmSync(srcDir, { recursive: true, force: true })
  rmSync(bareDir, { recursive: true, force: true })
})

describe.serial("Git integration (bare repo)", () => {
  describe.serial("currentBranch", () => {
    it("returns main", () =>
      run(
        Effect.gen(function* () {
          const branch = yield* currentBranch(WorktreePath(bareDir))
          expect(String(branch)).toBe("main")
        }),
      ))
  })

  describe.serial("repoRoot", () => {
    it("fails with GitRepoRootError on bare repo", async () => {
      const exit = await runExit(repoRoot(AbsolutePath(bareDir)))
      expect(Exit.isFailure(exit)).toBe(true)
    })
  })

  describe.serial("isWorktree", () => {
    it("returns false for the bare repo root", () =>
      runFull(
        Effect.gen(function* () {
          const result = yield* isWorktree(AbsolutePath(bareDir))
          expect(Option.isNone(result)).toBe(true)
        }),
      ))
  })

  describe.serial("worktreeList", () => {
    it("returns a single bare entry", () =>
      runFull(
        Effect.gen(function* () {
          const list = yield* worktreeList(GitCommonPath(bareDir))
          expect(list.length).toBe(1)
          expect(list[0]!.bare).toBe(true)
          expect(list[0]!.branch).toBeNull()
        }),
      ))
  })

  describe("worktree lifecycle", () => {
    const wtBranch = "bare-wt-test"
    let wtPath: string

    beforeAll(() =>
      runFull(
        Effect.gen(function* () {
          wtPath = `${bareDir}-wt-${wtBranch}`
          yield* git(bareDir, "branch", wtBranch)
          yield* worktreeAdd(BranchName(wtBranch), GitCommonPath(bareDir), { path: wtPath })
        }),
      ),
    )

    afterAll(() =>
      run(
        Effect.gen(function* () {
          yield* git(bareDir, "worktree", "remove", "--force", wtPath).pipe(Effect.ignore)
          yield* git(bareDir, "branch", "-D", wtBranch).pipe(Effect.ignore)
        }),
      ),
    )

    it("worktreeAdd creates a worktree from a bare repo", () =>
      runFull(
        Effect.gen(function* () {
          const list = yield* worktreeList(GitCommonPath(bareDir))
          const wt = list.find((w) => String(w.branch) === wtBranch)
          expect(wt).toBeDefined()
          expect(String(wt!.path)).toBe(wtPath)
          expect(String(wt!.branch)).toBe(wtBranch)
          expect(wt!.bare).toBe(false)
        }),
      ))

    it("repoRoot returns the worktree path (not the bare repo)", () =>
      run(
        Effect.gen(function* () {
          const root = yield* repoRoot(AbsolutePath(wtPath))
          expect(String(root)).toBe(wtPath)
        }),
      ))

    it("isWorktree returns true from inside the bare-repo worktree", () =>
      runFull(
        Effect.gen(function* () {
          const result = yield* isWorktree(AbsolutePath(wtPath))
          expect(Option.isSome(result)).toBe(true)
        }),
      ))

    it("currentBranch works from inside the worktree", () =>
      run(
        Effect.gen(function* () {
          const branch = yield* currentBranch(WorktreePath(wtPath))
          expect(String(branch)).toBe(wtBranch)
        }),
      ))

    it("isDirty returns false on clean worktree from bare repo", () =>
      run(
        Effect.gen(function* () {
          const result = yield* isDirty(WorktreePath(wtPath))
          expect(result).toBe(false)
        }),
      ))
  })

  describe("worktreeRemove on bare repo worktree", () => {
    const wtBranch = "bare-wt-rm-test"
    let wtPath: string

    beforeAll(() =>
      runFull(
        Effect.gen(function* () {
          wtPath = `${bareDir}-wt-${wtBranch}`
          yield* git(bareDir, "branch", wtBranch)
          yield* worktreeAdd(BranchName(wtBranch), GitCommonPath(bareDir), { path: wtPath })
        }),
      ),
    )

    afterAll(() =>
      run(
        Effect.gen(function* () {
          yield* git(bareDir, "worktree", "remove", "--force", wtPath).pipe(Effect.ignore)
          yield* git(bareDir, "branch", "-D", wtBranch).pipe(Effect.ignore)
        }),
      ),
    )

    it("removes the worktree", () =>
      runFull(
        Effect.gen(function* () {
          yield* worktreeRemove(WorktreePath(wtPath))
          const list = yield* worktreeList(GitCommonPath(bareDir))
          const wt = list.find((w) => String(w.branch) === wtBranch)
          expect(wt).toBeUndefined()
        }),
      ))
  })
})
