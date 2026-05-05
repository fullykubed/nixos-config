import { afterAll, beforeAll, describe, expect, it } from "bun:test"
import { rmSync } from "node:fs"
import { join } from "node:path"
import { Effect, Layer } from "effect"
import { BunContext } from "@effect/platform-bun"
import { ShellLive } from "../../Shell"
import { createBareRepo, createCloneRepo, createTmpRepo, git, run } from "./setup.test"
import { fetch } from "../public/fetch"
import { hasRemote } from "../public/has-remote"
import { remoteBranchExists } from "../public/remote-branch-exists"
import { BranchName, GitCommonPath } from "../types"

const FullLayer = ShellLive.pipe(Layer.provideMerge(BunContext.layer))

const _runFull = <A, E>(effect: Effect.Effect<A, E, any>): Promise<A> =>
  Effect.runPromise(effect.pipe(Effect.provide(FullLayer)) as Effect.Effect<A>)

let tmpDir: string
let srcDir: string
let bareDir: string
let cloneDir: string

beforeAll(async () => {
  tmpDir = await createTmpRepo()
  const repos = await createBareRepo()
  srcDir = repos.srcDir
  bareDir = repos.bareDir
  cloneDir = await createCloneRepo(bareDir)
})

afterAll(() => {
  rmSync(tmpDir, { recursive: true, force: true })
  rmSync(srcDir, { recursive: true, force: true })
  rmSync(bareDir, { recursive: true, force: true })
  rmSync(cloneDir, { recursive: true, force: true })
})

describe("Git integration (remote-awareness)", () => {
  describe("hasRemote", () => {
    it("returns true for origin on cloned repo", () =>
      run(
        Effect.gen(function* () {
          const gitDir = join(cloneDir, ".git")
          const result = yield* hasRemote("origin", GitCommonPath(gitDir))
          expect(result).toBe(true)
        }),
      ))

    it("returns false for non-existent remote name", () =>
      run(
        Effect.gen(function* () {
          const gitDir = join(cloneDir, ".git")
          const result = yield* hasRemote("upstream", GitCommonPath(gitDir))
          expect(result).toBe(false)
        }),
      ))

    it("returns false for non-existent remote on standalone repo", () =>
      run(
        Effect.gen(function* () {
          const gitDir = join(tmpDir, ".git")
          const result = yield* hasRemote("upstream", GitCommonPath(gitDir))
          expect(result).toBe(false)
        }),
      ))
  })

  describe("fetch", () => {
    it("fetches from origin without error", () =>
      run(
        Effect.gen(function* () {
          const gitDir = join(cloneDir, ".git")
          yield* fetch("origin", GitCommonPath(gitDir))
        }),
      ))
  })

  describe("remoteBranchExists", () => {
    it("returns true for origin/main on cloned repo", () =>
      run(
        Effect.gen(function* () {
          const gitDir = join(cloneDir, ".git")
          const result = yield* remoteBranchExists("origin", BranchName("main"), GitCommonPath(gitDir))
          expect(result).toBe(true)
        }),
      ))

    it("returns false for a branch that does not exist on origin", () =>
      run(
        Effect.gen(function* () {
          const gitDir = join(cloneDir, ".git")
          const result = yield* remoteBranchExists("origin", BranchName("no-such-branch-xyz"), GitCommonPath(gitDir))
          expect(result).toBe(false)
        }),
      ))

    it("returns false on a repo with no remotes", () =>
      run(
        Effect.gen(function* () {
          const gitDir = join(tmpDir, ".git")
          const result = yield* remoteBranchExists("origin", BranchName("main"), GitCommonPath(gitDir))
          expect(result).toBe(false)
        }),
      ))

    it("auto-fetches and finds newly pushed branches", () =>
      run(
        Effect.gen(function* () {
          // Push a new branch to the bare repo from srcDir
          yield* git(srcDir, "checkout", "-b", "auto-fetch-test")
          yield* git(srcDir, "commit", "--allow-empty", "-m", "auto-fetch test commit")
          yield* git(srcDir, "push", bareDir, "auto-fetch-test")

          // remoteBranchExists auto-fetches, so it should find the new branch
          const gitDir = join(cloneDir, ".git")
          const result = yield* remoteBranchExists("origin", BranchName("auto-fetch-test"), GitCommonPath(gitDir))
          expect(result).toBe(true)

          // Clean up
          yield* git(srcDir, "checkout", "main")
          yield* git(srcDir, "branch", "-D", "auto-fetch-test").pipe(Effect.ignore)
          yield* git(bareDir, "branch", "-D", "auto-fetch-test").pipe(Effect.ignore)
        }),
      ))
  })
})
