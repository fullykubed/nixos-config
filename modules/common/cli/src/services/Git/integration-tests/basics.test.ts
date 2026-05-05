import { afterAll, beforeAll, describe, expect, it } from "bun:test"
import { rmSync, writeFileSync } from "node:fs"
import { join } from "node:path"
import { Effect, Option, Layer } from "effect"
import { BunContext } from "@effect/platform-bun"
import { ShellLive } from "../../Shell"
import { createTmpRepo, git, run } from "./setup"
import { currentBranch } from "../public/current-branch"
import { isDirty } from "../public/is-dirty"
import { isWorktree } from "../public/is-worktree"
import { repoRoot } from "../public/repo-root"
import { worktreeList } from "../public/worktree-list"
import { AbsolutePath, WorktreePath, GitCommonPath } from "../types"

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

describe.serial("Git integration (basics)", () => {
  describe.serial("repoRoot", () => {
    it("returns the temp repo absolute path", () =>
      run(
        Effect.gen(function* () {
          const root = yield* repoRoot(AbsolutePath(tmpDir))
          expect(String(root)).toBe(tmpDir)
        }),
      ))
  })

  describe.serial("currentBranch", () => {
    it("returns main", () =>
      run(
        Effect.gen(function* () {
          const branch = yield* currentBranch(WorktreePath(tmpDir))
          expect(String(branch)).toBe("main")
        }),
      ))
  })

  describe.serial("isWorktree", () => {
    it("returns false for the main repo", () =>
      runFull(
        Effect.gen(function* () {
          const result = yield* isWorktree(AbsolutePath(tmpDir))
          expect(Option.isNone(result)).toBe(true)
        }),
      ))
  })

  describe.serial("isDirty", () => {
    it("returns false on a clean repo", () =>
      run(
        Effect.gen(function* () {
          const result = yield* isDirty(WorktreePath(tmpDir))
          expect(result).toBe(false)
        }),
      ))

    it("returns true with an untracked file", () =>
      run(
        Effect.gen(function* () {
          const file = join(tmpDir, "untracked.txt")
          writeFileSync(file, "hello")
          yield* Effect.gen(function* () {
            const result = yield* isDirty(WorktreePath(tmpDir))
            expect(result).toBe(true)
          }).pipe(Effect.ensuring(Effect.sync(() => { rmSync(file) })))
        }),
      ))

    it("returns true with a staged file", () =>
      run(
        Effect.gen(function* () {
          const file = join(tmpDir, "staged.txt")
          writeFileSync(file, "hello")
          yield* git(tmpDir, "add", "staged.txt")
          yield* Effect.gen(function* () {
            const result = yield* isDirty(WorktreePath(tmpDir))
            expect(result).toBe(true)
          }).pipe(
            Effect.ensuring(
              git(tmpDir, "reset", "HEAD", "staged.txt").pipe(
                Effect.andThen(Effect.sync(() => { rmSync(file) })),
                Effect.ignore,
              ),
            ),
          )
        }),
      ))
  })

  describe.serial("worktreeList", () => {
    it("returns a single main entry", () =>
      runFull(
        Effect.gen(function* () {
          const gitDir = join(tmpDir, ".git")
          const list = yield* worktreeList(GitCommonPath(gitDir))
          expect(list.length).toBe(1)
          expect(String(list[0]!.branch)).toBe("main")
          expect(String(list[0]!.path)).toBe(tmpDir)
          expect(String(list[0]!.branch)).toBe("main")
        }),
      ))
  })
})
