import { afterAll, beforeAll, describe, expect, it } from "bun:test"
import { existsSync, mkdtempSync, rmSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"

import { Effect, Layer, ManagedRuntime } from "effect"
import { SilentLogger } from "../../../lib/test-logger"
import { BunContext } from "@effect/platform-bun"
import { GitLive, GitService, GitCommonPath, ProjectPath, BranchName } from "../../Git"
import { TmuxLive } from "../../Tmux"
import { makeStoreLive, StoreService } from "../../Store"
import { ShellService } from "../../Shell"
import { makeIsolatedTmuxShell } from "../../Tmux/integration-tests/setup"
import { listWindows } from "../../Tmux/public/list-windows"
import { createWorktree } from "../public/create-worktree"
import { removeWorktree } from "../public/remove-worktree"
import { find } from "../public/find"
import { WorktreeId } from "../types"

const socket = `j-remove-wt-${process.pid}`

const TestLayer = Layer.mergeAll(
  GitLive,
  TmuxLive,
  makeStoreLive(":memory:"),
).pipe(
  Layer.provideMerge(makeIsolatedTmuxShell(socket)),
  Layer.provideMerge(BunContext.layer),
  Layer.merge(SilentLogger),
)

describe.serial("removeWorktree integration", () => {
  const runtime = ManagedRuntime.make(TestLayer)

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
  let originalCwd: string

  beforeAll(async () => {
    originalCwd = process.cwd()

    const srcDir = mkdtempSync(join(tmpdir(), "rmwt-src-"))
    originDir = mkdtempSync(join(tmpdir(), "rmwt-origin-")) + ".git"
    cloneDir = mkdtempSync(join(tmpdir(), "rmwt-clone-"))

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

  afterAll(async () => {
    process.chdir(originalCwd)
    await run(tmuxCmd("kill-server")).catch(() => { /* noop */ })
    await runtime.dispose()
    if (existsSync(originDir)) rmSync(originDir, { recursive: true, force: true })
    if (existsSync(cloneDir)) rmSync(cloneDir, { recursive: true, force: true })
  })

  it("removes git worktree, branch, tmux window, and soft-deletes DB record", async () => {
    // Create a worktree first
    await run(createWorktree(ProjectPath(cloneDir), BranchName("feature-remove")))

    // Verify setup: worktree exists, window exists, DB record exists
    const worktreesBefore = await run(Effect.gen(function* () {
      const git = yield* GitService
      return yield* git.worktreeList(GitCommonPath(cloneDir))
    }))
    expect(worktreesBefore.find(w => w.branch === "feature-remove")).toBeDefined()

    const windowsBefore = await run(listWindows())
    expect(windowsBefore.some(w => w.name.includes("feature-remove"))).toBe(true)

    const dbEntryBefore = await run(find(cloneDir, BranchName("feature-remove")))
    expect(dbEntryBefore).not.toBeNull()
    const worktreeId = WorktreeId(dbEntryBefore!.id)

    // Remove the worktree
    const result = await run(removeWorktree(worktreeId))
    expect(result.windowClosed).toBe(true)

    // Verify: git worktree removed
    const worktreesAfter = await run(Effect.gen(function* () {
      const git = yield* GitService
      return yield* git.worktreeList(GitCommonPath(cloneDir))
    }))
    expect(worktreesAfter.find(w => w.branch === "feature-remove")).toBeUndefined()

    // Verify: branch deleted
    const branches = await run(gitCmd(cloneDir, "branch", "--list", "feature-remove"))
    expect(branches).toBe("")

    // Verify: tmux window killed
    const windowsAfter = await run(listWindows())
    expect(windowsAfter.some(w => w.name.includes("feature-remove"))).toBe(false)

    // Verify: DB record soft-deleted (find returns null)
    const dbEntryAfter = await run(find(cloneDir, BranchName("feature-remove")))
    expect(dbEntryAfter).toBeNull()

    // Verify: DB record still exists with deleted_at set
    const rawRow = await run(Effect.gen(function* () {
      const db = yield* StoreService
      return yield* Effect.tryPromise(() =>
        db.selectFrom("mux_worktrees")
          .selectAll()
          .where("branch", "=", "feature-remove")
          .executeTakeFirst()
      )
    }))
    expect(rawRow).toBeDefined()
    expect(rawRow!.deleted_at).not.toBeNull()
  })

  it("returns windowClosed: false when tmux window was already closed", async () => {
    await run(createWorktree(ProjectPath(cloneDir), BranchName("feature-no-window")))

    const dbEntry = await run(find(cloneDir, BranchName("feature-no-window")))
    expect(dbEntry).not.toBeNull()
    const worktreeId = WorktreeId(dbEntry!.id)

    // Kill the tmux window manually before calling removeWorktree
    const windows = await run(listWindows())
    const targetWindow = windows.find(w => w.name.includes("feature-no-window"))
    if (targetWindow) {
      await run(tmuxCmd("kill-window", "-t", targetWindow.id))
    }

    const result = await run(removeWorktree(worktreeId))
    expect(result.windowClosed).toBe(false)

    // Verify cleanup still happened
    const worktreesAfter = await run(Effect.gen(function* () {
      const git = yield* GitService
      return yield* git.worktreeList(GitCommonPath(cloneDir))
    }))
    expect(worktreesAfter.find(w => w.branch === "feature-no-window")).toBeUndefined()

    const branchList = await run(gitCmd(cloneDir, "branch", "--list", "feature-no-window"))
    expect(branchList).toBe("")
  })

  it("succeeds silently when worktree id does not exist in DB", async () => {
    const fakeId = WorktreeId("00000000-0000-0000-0000-ffffffffffff")
    const result = await run(removeWorktree(fakeId))
    expect(result.windowClosed).toBe(false)
  })
})
