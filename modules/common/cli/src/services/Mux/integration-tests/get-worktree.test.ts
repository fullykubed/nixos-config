import { afterAll, beforeAll, describe, expect, it } from "bun:test"
import { existsSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"

import { Effect, Layer, ManagedRuntime, Option } from "effect"
import { SilentLogger } from "../../../lib/test/logger"
import { BunContext } from "@effect/platform-bun"
import { AbsolutePath, GitLive, GitService, GitCommonPath, ProjectPath, BranchName } from "../../Git"
import { TmuxLive } from "../../Tmux"
import { makeStoreLive } from "../../Store"
import { ShellService } from "../../Shell"
import { makeIsolatedTmuxShell } from "../../Tmux/integration-tests/setup.test"
import { createWorktree } from "../public/create-worktree"
import { getWorktreeFromBranch } from "../public/get-worktree-from-branch"
import { getWorktreeFromPath } from "../public/get-worktree-from-path"
import { getWorktreeById } from "../public/get-worktree-by-id"
import { WorktreeId } from "../types"

/** Build a fresh layer per describe block to avoid shared memoization. */
const makeTestLayer = (socket: string) =>
  Layer.mergeAll(
    GitLive,
    TmuxLive,
    makeStoreLive(":memory:"),
  ).pipe(
    Layer.provideMerge(makeIsolatedTmuxShell(socket)),
    Layer.provideMerge(BunContext.layer),
    Layer.merge(SilentLogger),
  )

describe.serial("getWorktreeFromBranch integration", () => {
  const socket = `j-get-wt-br-${process.pid}`
  const runtime = ManagedRuntime.make(makeTestLayer(socket))

  const run = <A, E>(effect: Effect.Effect<A, E, any>) =>
    runtime.runPromise(effect)

  const gitCmd = (cwd: string, ...args: string[]) =>
    Effect.gen(function* () {
      const shell = yield* ShellService
      const { stdout } = yield* shell.exec("git", args, { cwd })
      return stdout.trim()
    })

  const tmuxCmd = (...args: string[]) =>
    Effect.gen(function* () {
      const shell = yield* ShellService
      const { stdout } = yield* shell.exec("tmux", args)
      return stdout.trim()
    })

  let originDir: string
  let cloneDir: string

  beforeAll(async () => {
    const srcDir = mkdtempSync(join(tmpdir(), "getwt-src-"))
    originDir = mkdtempSync(join(tmpdir(), "getwt-origin-")) + ".git"
    cloneDir = mkdtempSync(join(tmpdir(), "getwt-clone-"))

    await run(Effect.gen(function* () {
      yield* gitCmd(srcDir, "init", "-b", "main")
      yield* gitCmd(srcDir, "config", "user.name", "Test")
      yield* gitCmd(srcDir, "config", "user.email", "test@test.com")
      yield* gitCmd(srcDir, "commit", "--allow-empty", "-m", "initial")
      yield* gitCmd(srcDir, "clone", "--bare", srcDir, originDir)

      const shell = yield* ShellService
      yield* shell.exec("git", ["clone", originDir, cloneDir])
      yield* gitCmd(cloneDir, "config", "user.name", "Test")
      yield* gitCmd(cloneDir, "config", "user.email", "test@test.com")
    }))

    writeFileSync(join(cloneDir, ".git", "project.json"), JSON.stringify({
      tmux_session: "test",
      worktree: { files: { copy: [], link: [] }, panes: [], post_create: [] },
    }))

    await run(tmuxCmd("new-session", "-d", "-s", "test", "-x", "200", "-y", "50"))

    rmSync(srcDir, { recursive: true, force: true })
  })

  afterAll(async () => {
    await run(tmuxCmd("kill-server")).catch(() => { /* noop */ })
    await runtime.dispose()
    if (existsSync(originDir)) rmSync(originDir, { recursive: true, force: true })
    if (existsSync(cloneDir)) rmSync(cloneDir, { recursive: true, force: true })
  })

  it("returns the worktree entry for a created worktree", async () => {
    await run(createWorktree(ProjectPath(cloneDir), BranchName("feature-get-by-branch")))

    const result = await run(getWorktreeFromBranch(ProjectPath(cloneDir), BranchName("feature-get-by-branch")))
    expect(Option.isSome(result)).toBe(true)
    const wt = Option.getOrThrow(result)
    expect(String(wt.branch)).toBe("feature-get-by-branch")
  })

  it("returns None for a branch that does not exist", async () => {
    const result = await run(getWorktreeFromBranch(ProjectPath(cloneDir), BranchName("nonexistent-branch")))
    expect(Option.isNone(result)).toBe(true)
  })

  it("returns None for a wrong project path", async () => {
    const result = await run(getWorktreeFromBranch(ProjectPath("/wrong/path"), BranchName("feature-get-by-branch")))
    expect(Option.isNone(result)).toBe(true)
  })

  it("returns the same entry via getWorktreeById", async () => {
    await run(createWorktree(ProjectPath(cloneDir), BranchName("feature-get-by-id"))).catch(() => { /* already exists */ })

    const byBranch = await run(getWorktreeFromBranch(ProjectPath(cloneDir), BranchName("feature-get-by-id")))
    expect(Option.isSome(byBranch)).toBe(true)
    const branchEntry = Option.getOrThrow(byBranch)

    const byId = await run(getWorktreeById(WorktreeId(branchEntry.id)))
    expect(Option.isSome(byId)).toBe(true)
    const idEntry = Option.getOrThrow(byId)
    expect(idEntry.id).toBe(branchEntry.id)
    expect(idEntry.branch).toBe(branchEntry.branch)
    expect(idEntry.project_path).toBe(branchEntry.project_path)
  })

  it("getWorktreeById returns None for non-existent id", async () => {
    const result = await run(getWorktreeById(WorktreeId("00000000-0000-0000-0000-ffffffffffff")))
    expect(Option.isNone(result)).toBe(true)
  })
})

describe.serial("getWorktreeFromPath integration", () => {
  const socket = `j-get-wt-pa-${process.pid}`
  const runtime = ManagedRuntime.make(makeTestLayer(socket))

  const run = <A, E>(effect: Effect.Effect<A, E, any>) =>
    runtime.runPromise(effect)

  const gitCmd = (cwd: string, ...args: string[]) =>
    Effect.gen(function* () {
      const shell = yield* ShellService
      const { stdout } = yield* shell.exec("git", args, { cwd })
      return stdout.trim()
    })

  const tmuxCmd = (...args: string[]) =>
    Effect.gen(function* () {
      const shell = yield* ShellService
      const { stdout } = yield* shell.exec("tmux", args)
      return stdout.trim()
    })

  let originDir: string
  let cloneDir: string

  beforeAll(async () => {
    const srcDir = mkdtempSync(join(tmpdir(), "getwtp-src-"))
    originDir = mkdtempSync(join(tmpdir(), "getwtp-origin-")) + ".git"
    cloneDir = mkdtempSync(join(tmpdir(), "getwtp-clone-"))

    await run(Effect.gen(function* () {
      yield* gitCmd(srcDir, "init", "-b", "main")
      yield* gitCmd(srcDir, "config", "user.name", "Test")
      yield* gitCmd(srcDir, "config", "user.email", "test@test.com")
      yield* gitCmd(srcDir, "commit", "--allow-empty", "-m", "initial")
      yield* gitCmd(srcDir, "clone", "--bare", srcDir, originDir)

      const shell = yield* ShellService
      yield* shell.exec("git", ["clone", originDir, cloneDir])
      yield* gitCmd(cloneDir, "config", "user.name", "Test")
      yield* gitCmd(cloneDir, "config", "user.email", "test@test.com")
    }))

    writeFileSync(join(cloneDir, ".git", "project.json"), JSON.stringify({
      tmux_session: "test-path",
      worktree: { files: { copy: [], link: [] }, panes: [], post_create: [] },
    }))

    await run(tmuxCmd("new-session", "-d", "-s", "test-path", "-x", "200", "-y", "50"))

    rmSync(srcDir, { recursive: true, force: true })
  })

  afterAll(async () => {
    await run(tmuxCmd("kill-server")).catch(() => { /* noop */ })
    await runtime.dispose()
    if (existsSync(originDir)) rmSync(originDir, { recursive: true, force: true })
    if (existsSync(cloneDir)) rmSync(cloneDir, { recursive: true, force: true })
  })

  it("returns the worktree entry when given the worktree path", async () => {
    await run(createWorktree(ProjectPath(cloneDir), BranchName("feature-get-by-path")))

    const worktrees = await run(Effect.gen(function* () {
      const git = yield* GitService
      return yield* git.worktreeList(GitCommonPath(cloneDir))
    }))
    const wt = worktrees.find(w => w.branch === "feature-get-by-path")
    expect(wt).toBeDefined()

    const result = await run(getWorktreeFromPath(wt!.path))
    expect(Option.isSome(result)).toBe(true)
    expect(String(Option.getOrThrow(result).branch)).toBe("feature-get-by-path")
  })

  it("returns Some when given a path inside the worktree", async () => {
    await run(createWorktree(ProjectPath(cloneDir), BranchName("feature-subdir")))

    const worktrees = await run(Effect.gen(function* () {
      const git = yield* GitService
      return yield* git.worktreeList(GitCommonPath(cloneDir))
    }))
    const wt = worktrees.find(w => w.branch === "feature-subdir")
    expect(wt).toBeDefined()

    const subdir = join(wt!.path, "src", "nested")
    mkdirSync(subdir, { recursive: true })
    const result = await run(getWorktreeFromPath(AbsolutePath(subdir)))
    expect(Option.isSome(result)).toBe(true)
    expect(String(Option.getOrThrow(result).branch)).toBe("feature-subdir")
  })

  it("returns None for a path that is not tracked in mux", async () => {
    const worktrees = await run(Effect.gen(function* () {
      const git = yield* GitService
      return yield* git.worktreeList(GitCommonPath(cloneDir))
    }))

    const primaryWt = worktrees.find(w => w.branch === "main")
    expect(primaryWt).toBeDefined()

    const result = await run(getWorktreeFromPath(primaryWt!.path))
    expect(Option.isNone(result)).toBe(true)
  })
})
