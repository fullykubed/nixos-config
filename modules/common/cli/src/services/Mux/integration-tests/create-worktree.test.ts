import { afterAll, afterEach, beforeAll, describe, expect, it } from "bun:test"
import { existsSync, mkdtempSync, rmSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"

import { Effect, Exit, Layer, ManagedRuntime } from "effect"
import { SilentLogger } from "../../../lib/test-logger"
import { sql } from "kysely"
import { BunContext } from "@effect/platform-bun"
import { GitLive, GitService, GitCommonPath, ProjectPath, BranchName } from "../../Git"
import { TmuxLive } from "../../Tmux"
import { makeStoreLive, StoreService } from "../../Store"
import { ShellService } from "../../Shell"
import { makeIsolatedTmuxShell } from "../../Tmux/integration-tests/setup"
import { listWindows } from "../../Tmux/public/list-windows"
import { createWorktree } from "../public/create-worktree"

const socket = `j-create-wt-${process.pid}`

const TestLayer = Layer.mergeAll(
  GitLive,
  TmuxLive,
  makeStoreLive(":memory:"),
).pipe(
  Layer.provideMerge(makeIsolatedTmuxShell(socket)),
  Layer.provideMerge(BunContext.layer),
  Layer.merge(SilentLogger),
)

describe.serial("createWorktree integration", () => {
  const runtime = ManagedRuntime.make(TestLayer)

  const run = <A, E>(effect: Effect.Effect<A, E, any>) =>
    runtime.runPromise(effect)

  const runExit = <A, E>(effect: Effect.Effect<A, E, any>) =>
    runtime.runPromiseExit(effect)

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
  let originalCwd: string
  let createdBranches: string[] = []

  beforeAll(async () => {
    originalCwd = process.cwd()

    const srcDir = mkdtempSync(join(tmpdir(), "cwt-src-"))
    originDir = mkdtempSync(join(tmpdir(), "cwt-origin-")) + ".git"
    cloneDir = mkdtempSync(join(tmpdir(), "cwt-clone-"))

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
    process.chdir(cloneDir)

    rmSync(srcDir, { recursive: true, force: true })
  })

  afterEach(async () => {
    for (const branch of createdBranches) {
      const worktrees = await run(Effect.gen(function* () {
        const git = yield* GitService
        return yield* git.worktreeList(GitCommonPath(cloneDir))
      }))
      const wt = worktrees.find(w => w.branch === branch)
      if (wt && !wt.isPrimary) {
        await run(gitCmd(cloneDir, "worktree", "remove", "--force", wt.path).pipe(Effect.ignore))
      }
      await run(gitCmd(cloneDir, "branch", "-D", branch).pipe(Effect.ignore))
    }
    createdBranches = []
  })

  afterAll(async () => {
    process.chdir(originalCwd)
    await run(tmuxCmd("kill-server")).catch(() => { /* noop */ })
    await runtime.dispose()
    if (existsSync(originDir)) rmSync(originDir, { recursive: true, force: true })
    if (existsSync(cloneDir)) rmSync(cloneDir, { recursive: true, force: true })
  })

  it("creates worktree, records it in DB, and opens tmux window", async () => {
    createdBranches.push("feature-1")

    await run(createWorktree(ProjectPath(cloneDir), BranchName("feature-1")))

    // Verify: worktree exists on filesystem
    const worktrees = await run(Effect.gen(function* () {
      const git = yield* GitService
      return yield* git.worktreeList(GitCommonPath(cloneDir))
    }))
    const wt = worktrees.find(w => w.branch === "feature-1")
    expect(wt).toBeDefined()
    expect(existsSync(wt!.path)).toBe(true)

    // Verify: DB has worktree record
    const dbWorktree = await run(Effect.gen(function* () {
      const db = yield* StoreService
      return yield* Effect.tryPromise(() =>
        db.selectFrom("mux_worktrees")
          .selectAll()
          .where("branch", "=", "feature-1")
          .executeTakeFirst()
      )
    }))
    expect(dbWorktree).toBeDefined()
    expect(dbWorktree!.branch).toBe("feature-1")

    // Verify: DB has project record linked to worktree
    const dbProject = await run(Effect.gen(function* () {
      const db = yield* StoreService
      return yield* Effect.tryPromise(() =>
        db.selectFrom("mux_projects")
          .selectAll()
          .where("id", "=", dbWorktree!.project_id)
          .executeTakeFirst()
      )
    }))
    expect(dbProject).toBeDefined()
    expect(dbProject!.path).toContain("cwt-clone-")

    // Verify: tmux window exists
    const windows = await run(listWindows())
    const hasWindow = windows.some(w => w.name.includes("feature-1"))
    expect(hasWindow).toBe(true)
  })

  it("fails with MuxBranchExistsOnRemoteError when branch exists on origin", async () => {
    createdBranches.push("remote-conflict")

    await run(Effect.gen(function* () {
      yield* gitCmd(cloneDir, "branch", "remote-conflict")
      yield* gitCmd(cloneDir, "push", "origin", "remote-conflict")
    }))

    const exit = await runExit(createWorktree(ProjectPath(cloneDir), BranchName("remote-conflict")))

    expect(Exit.isFailure(exit)).toBe(true)
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      expect(exit.cause.error._tag).toBe("MuxBranchExistsOnRemoteError")
      if (exit.cause.error._tag === "MuxBranchExistsOnRemoteError") {
        expect(exit.cause.error.branch).toBe("remote-conflict")
      }
    }

    await run(gitCmd(cloneDir, "push", "origin", "--delete", "remote-conflict").pipe(Effect.ignore))
  })

  it("fails with MuxBranchExistsLocallyError when local branch exists", async () => {
    createdBranches.push("local-conflict")
    await run(gitCmd(cloneDir, "branch", "local-conflict"))

    const exit = await runExit(createWorktree(ProjectPath(cloneDir), BranchName("local-conflict")))

    expect(Exit.isFailure(exit)).toBe(true)
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      expect(exit.cause.error._tag).toBe("MuxBranchExistsLocallyError")
      if (exit.cause.error._tag === "MuxBranchExistsLocallyError") {
        expect(exit.cause.error.branch).toBe("local-conflict")
        expect(exit.cause.error.hasWorktree).toBe(false)
      }
    }
  })

  it("cleans up window, worktree, branch, and DB entry when trackWorktree fails", async () => {
    createdBranches.push("cleanup-full")

    // Install a SQLite trigger that rejects INSERT for this specific branch.
    // This makes trackWorktree fail AFTER the tmux window is already created,
    // exercising the full cleanup path (window + worktree + branch + DB).
    await run(Effect.gen(function* () {
      const db = yield* StoreService
      yield* Effect.tryPromise(() =>
        sql`CREATE TRIGGER fail_cleanup_full
            BEFORE INSERT ON mux_worktrees
            WHEN NEW.branch = 'cleanup-full'
            BEGIN SELECT RAISE(ABORT, 'deliberate test failure'); END`.execute(db)
      )
    }))

    const exit = await runExit(createWorktree(ProjectPath(cloneDir), BranchName("cleanup-full")))

    // Drop trigger so it doesn't affect other tests
    await run(Effect.gen(function* () {
      const db = yield* StoreService
      yield* Effect.tryPromise(() =>
        sql`DROP TRIGGER IF EXISTS fail_cleanup_full`.execute(db)
      )
    }))

    expect(Exit.isFailure(exit)).toBe(true)
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      expect(exit.cause.error._tag).toBe("MuxCreateWorktreeError")
    }

    // Verify: tmux window was killed
    const windows = await run(listWindows())
    expect(windows.some(w => w.name.includes("cleanup-full"))).toBe(false)

    // Verify: worktree was removed from filesystem
    const worktrees = await run(Effect.gen(function* () {
      const git = yield* GitService
      return yield* git.worktreeList(GitCommonPath(cloneDir))
    }))
    expect(worktrees.find(w => w.branch === "cleanup-full")).toBeUndefined()

    // Verify: branch was deleted from git
    const branches = await run(gitCmd(cloneDir, "branch", "--list", "cleanup-full"))
    expect(branches).toBe("")

    // Verify: no DB entry exists
    const dbEntry = await run(Effect.gen(function* () {
      const db = yield* StoreService
      return yield* Effect.tryPromise(() =>
        db.selectFrom("mux_worktrees")
          .selectAll()
          .where("branch", "=", "cleanup-full")
          .executeTakeFirst()
      )
    }))
    expect(dbEntry).toBeUndefined()
  })
})
