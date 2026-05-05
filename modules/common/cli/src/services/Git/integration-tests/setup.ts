/* eslint-disable no-restricted-imports -- test infrastructure, not production code */
import { mkdtempSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"
/* eslint-enable no-restricted-imports */
import { Effect, Exit, Layer } from "effect"
import { BunContext } from "@effect/platform-bun"
import { ShellLive, ShellService } from "../../Shell"

const TestLayer = ShellLive.pipe(Layer.provideMerge(BunContext.layer))

export const run = <A, E>(effect: Effect.Effect<A, E, ShellService>) =>
  effect.pipe(Effect.provide(TestLayer), Effect.runPromise)

export const runExit = <A, E>(effect: Effect.Effect<A, E, ShellService>) =>
  effect.pipe(Effect.provide(TestLayer), Effect.runPromiseExit)

/** Run a raw git command for test setup (not the Git service under test). */
export const git = (cwd: string, ...args: string[]) =>
  Effect.gen(function* () {
    const shell = yield* ShellService
    const { stdout } = yield* shell.exec("git", args, { cwd })
    return stdout.trim()
  })

/** Create a temporary repo with git init, user config, and an empty initial commit. */
export const createTmpRepo = (): Promise<string> =>
  run(
    Effect.gen(function* () {
      const dir = mkdtempSync(join(tmpdir(), "git-integ-"))
      yield* git(dir, "init", "-b", "main")
      yield* git(dir, "config", "user.name", "Test")
      yield* git(dir, "config", "user.email", "test@test.com")
      yield* git(dir, "commit", "--allow-empty", "-m", "initial")
      return dir
    }),
  )

/** Create a scratch repo + bare clone. Returns both paths. */
export const createBareRepo = (): Promise<{ srcDir: string; bareDir: string }> =>
  run(
    Effect.gen(function* () {
      const srcDir = mkdtempSync(join(tmpdir(), "git-integ-src-"))
      yield* git(srcDir, "init", "-b", "main")
      yield* git(srcDir, "config", "user.name", "Test")
      yield* git(srcDir, "config", "user.email", "test@test.com")
      yield* git(srcDir, "commit", "--allow-empty", "-m", "initial")
      const bareDir = mkdtempSync(join(tmpdir(), "git-integ-bare-")) + ".git"
      yield* git(srcDir, "clone", "--bare", srcDir, bareDir)
      return { srcDir, bareDir }
    }),
  )

/** Clone a bare repo — the clone has "origin" pointing at bareDir. */
export const createCloneRepo = (bareDir: string): Promise<string> =>
  run(
    Effect.gen(function* () {
      const cloneDir = mkdtempSync(join(tmpdir(), "git-integ-clone-"))
      yield* git(cloneDir, "clone", bareDir, cloneDir)
      yield* git(cloneDir, "config", "user.name", "Test")
      yield* git(cloneDir, "config", "user.email", "test@test.com")
      return cloneDir
    }),
  )

/** Helper to extract a Fail cause from an Exit. */
export const extractError = <E>(exit: Exit.Exit<unknown, E>): E => {
  if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
    return exit.cause.error
  }
  throw new Error("Expected Fail cause")
}
