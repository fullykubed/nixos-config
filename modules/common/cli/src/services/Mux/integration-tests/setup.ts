/* eslint-disable no-restricted-imports -- test infrastructure, not production code */
import { mkdtempSync, writeFileSync, mkdirSync, readFileSync, existsSync, lstatSync, readlinkSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"
/* eslint-enable no-restricted-imports */
import { Effect, Layer } from "effect"
import { SilentLogger } from "../../../lib/test-logger"
import { BunContext } from "@effect/platform-bun"
import { FileSystem, Path } from "@effect/platform"
import { ShellLive, ShellService } from "../../Shell"
import { GitLive, GitService } from "../../Git"

// ── Layer ───────────────────────────────────────────────────────────

export const TestLayer = GitLive.pipe(
  Layer.provideMerge(ShellLive),
  Layer.provideMerge(BunContext.layer),
  Layer.merge(SilentLogger),
)

type TestDeps = ShellService | GitService | FileSystem.FileSystem | Path.Path

export const run = <A, E>(effect: Effect.Effect<A, E, TestDeps>) =>
  effect.pipe(Effect.provide(TestLayer), Effect.runPromise)

/** Run a raw git command for test setup (not the service under test). */
export const git = (cwd: string, ...args: string[]) =>
  Effect.gen(function* () {
    const shell = yield* ShellService
    const { stdout } = yield* shell.exec("git", args, { cwd })
    return stdout.trim()
  })

// ── File helpers ────────────────────────────────────────────────────

/**
 * A test repo fixture. `primaryDir` is where untracked files live (the main worktree).
 * `gitDir` is the git common dir used as cwd for worktree operations.
 * `configDir` is where project.json should be written.
 */
export interface RepoFixture {
  /** The primary worktree directory (where files live). */
  primaryDir: string
  /** The git common dir — use as cwd for git worktree add/remove. */
  gitDir: string
  /** Where project.json should be placed. */
  configDir: string
  /** All directories to clean up. */
  cleanupDirs: string[]
}

/** Create a normal git repo. primaryDir = gitDir = configDir. */
export const createNormalRepo = (): Promise<RepoFixture> =>
  run(
    Effect.gen(function* () {
      const dir = mkdtempSync(join(tmpdir(), "mux-integ-"))
      yield* git(dir, "init", "-b", "main")
      yield* git(dir, "config", "user.name", "Test")
      yield* git(dir, "config", "user.email", "test@test.com")
      yield* git(dir, "commit", "--allow-empty", "-m", "initial")
      return { primaryDir: dir, gitDir: dir, configDir: dir, cleanupDirs: [dir] }
    }),
  )

/**
 * Create a bare worktree repo layout:
 *   <root>/.bare/   — bare git repo
 *   <root>/main/    — primary worktree checked out to "main"
 *   <root>/project.json — config lives at root
 */
export const createBareWorktreeRepo = (): Promise<RepoFixture> =>
  run(
    Effect.gen(function* () {
      const root = mkdtempSync(join(tmpdir(), "mux-integ-bare-"))
      const bareDir = join(root, ".bare")
      const mainDir = join(root, "main")

      // Init a temp repo, then clone it as bare
      const tmpSrc = mkdtempSync(join(tmpdir(), "mux-integ-src-"))
      yield* git(tmpSrc, "init", "-b", "main")
      yield* git(tmpSrc, "config", "user.name", "Test")
      yield* git(tmpSrc, "config", "user.email", "test@test.com")
      yield* git(tmpSrc, "commit", "--allow-empty", "-m", "initial")
      yield* git(tmpSrc, "clone", "--bare", tmpSrc, bareDir)

      // Create primary worktree
      yield* git(bareDir, "worktree", "add", mainDir, "main")
      yield* git(mainDir, "config", "user.name", "Test")
      yield* git(mainDir, "config", "user.email", "test@test.com")

      return { primaryDir: mainDir, gitDir: bareDir, configDir: root, cleanupDirs: [root, tmpSrc] }
    }),
  )

export const writeFile = (dir: string, relativePath: string, content: string) => {
  const fullPath = join(dir, relativePath)
  mkdirSync(join(fullPath, ".."), { recursive: true })
  writeFileSync(fullPath, content)
}

export const readFile = (dir: string, relativePath: string) =>
  readFileSync(join(dir, relativePath), "utf-8")

export const exists = (dir: string, relativePath: string) =>
  existsSync(join(dir, relativePath))

export const isSymlink = (dir: string, relativePath: string) =>
  lstatSync(join(dir, relativePath)).isSymbolicLink()

export const readlink = (dir: string, relativePath: string) =>
  readlinkSync(join(dir, relativePath))

