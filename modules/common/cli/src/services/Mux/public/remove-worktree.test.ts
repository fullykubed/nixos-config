import { describe, it, expect, mock } from "bun:test"
import { Effect, Context } from "effect"
import { makeStoreLive, StoreService } from "../../Store"
import { ProjectId, ProjectPath, BranchName } from "../../Git"
import { WorktreeId } from "../types"
import { trackProject } from "../internal/track-project"
import { trackWorktree } from "../internal/track-worktree"
import { removeWorktree } from "./remove-worktree"
import { TmuxService } from "../../Tmux"
import { ShellService } from "../../Shell"
import { GitService } from "../../Git"

const PID_1 = ProjectId("cccccccc-0000-0000-0000-000000000001")
const PID_2 = ProjectId("cccccccc-0000-0000-0000-000000000002")
const PID_3 = ProjectId("cccccccc-0000-0000-0000-000000000003")
const PID_4 = ProjectId("cccccccc-0000-0000-0000-000000000004")

const WID_1 = WorktreeId("dddddddd-0000-0000-0000-000000000001")
const WID_2 = WorktreeId("dddddddd-0000-0000-0000-000000000002")
const WID_3 = WorktreeId("dddddddd-0000-0000-0000-000000000003")
const WID_4 = WorktreeId("dddddddd-0000-0000-0000-000000000004")
const WID_5 = WorktreeId("dddddddd-0000-0000-0000-000000000005")
const WID_6 = WorktreeId("dddddddd-0000-0000-0000-000000000006")
const WID_NONEXISTENT = WorktreeId("dddddddd-0000-0000-0000-ffffffffffff")

/** Direct DB query — returns active (non-deleted) worktree rows. */
const queryActiveWorktrees = Effect.gen(function* () {
  const db = yield* StoreService
  return yield* Effect.tryPromise(() =>
    db.selectFrom("mux_worktrees as w")
      .innerJoin("mux_projects as p", "p.id", "w.project_id")
      .select(["w.id as id", "w.branch", "p.path as project_path"])
      .where("w.deleted_at", "is", null)
      .orderBy("w.branch", "asc")
      .execute()
  )
})

describe("removeWorktree", () => {
  const TestStore = makeStoreLive(":memory:")

  /** Mock shell that returns the given stdout for tmux list-windows. */
  const makeShellMock = (listWindowsStdout = "") => Context.empty().pipe(
    Context.add(ShellService, {
      exec: () => Effect.succeed({ stdout: listWindowsStdout, stderr: "", exitCode: 0 }),
    } as any)
  )

  const makeTmuxMock = (overrides = {}) => Context.empty().pipe(
    Context.add(TmuxService, {
      killWindow: () => Effect.succeed(undefined),
      ...overrides,
    } as any)
  )

  const makeGitMock = (overrides = {}) => Context.empty().pipe(
    Context.add(GitService, {
      commonDir: () => Effect.succeed("/stub/.git"),
      worktreeList: () => Effect.succeed([]),
      worktreeRemove: () => Effect.void,
      deleteBranch: () => Effect.void,
      ...overrides,
    } as any)
  )

  const run = <A, E>(
    effect: Effect.Effect<A, E, any>,
    opts: { tmux?: Record<string, unknown>; git?: Record<string, unknown>; shellStdout?: string } = {},
  ) =>
    Effect.runPromise(effect.pipe(
      Effect.provide(TestStore),
      Effect.provide(makeTmuxMock(opts.tmux)),
      Effect.provide(makeGitMock(opts.git)),
      Effect.provide(makeShellMock(opts.shellStdout)),
    ) as Effect.Effect<A, E>)

  it("soft-deletes an existing worktree record", async () => {
    await run(Effect.gen(function* () {
      yield* trackProject(PID_1, ProjectPath("/home/user/repo"))
      yield* trackWorktree(PID_1, BranchName("feature/remove-test"), WID_1)

      let rows = yield* queryActiveWorktrees
      expect(rows.filter(r => r.project_path === "/home/user/repo" && r.branch === "feature/remove-test")).toHaveLength(1)

      yield* removeWorktree(WID_1)

      rows = yield* queryActiveWorktrees
      expect(rows.filter(r => r.project_path === "/home/user/repo" && r.branch === "feature/remove-test")).toHaveLength(0)
    }))
  })

  it("sets deleted_at timestamp instead of hard deleting", async () => {
    await run(Effect.gen(function* () {
      yield* trackProject(PID_2, ProjectPath("/home/user/repo-soft"))
      yield* trackWorktree(PID_2, BranchName("feature/soft-check"), WID_2)

      yield* removeWorktree(WID_2)

      const db = yield* StoreService
      const row = yield* Effect.tryPromise(() =>
        db.selectFrom("mux_worktrees")
          .selectAll()
          .where("branch", "=", BranchName("feature/soft-check"))
          .executeTakeFirst()
      )
      expect(row).toBeDefined()
      expect(row!.deleted_at).not.toBeNull()
    }))
  })

  it("soft-deletes only the specified record", async () => {
    await run(Effect.gen(function* () {
      yield* trackProject(PID_3, ProjectPath("/home/user/repo2"))
      yield* trackProject(PID_4, ProjectPath("/home/user/other-repo"))
      yield* trackWorktree(PID_3, BranchName("feature/keep"), WID_3)
      yield* trackWorktree(PID_3, BranchName("feature/remove"), WID_4)
      yield* trackWorktree(PID_4, BranchName("feature/keep-other"), WID_5)

      let rows = yield* queryActiveWorktrees
      expect(rows).toHaveLength(3)

      yield* removeWorktree(WID_4)

      rows = yield* queryActiveWorktrees
      expect(rows).toHaveLength(2)

      const remainingBranches = rows.map(r => r.branch) as string[]
      expect(remainingBranches).toContain("feature/keep")
      expect(remainingBranches).toContain("feature/keep-other")
      expect(remainingBranches).not.toContain("feature/remove")
    }))
  })

  it("silently succeeds when removing non-existent record", async () => {
    await run(Effect.gen(function* () {
      yield* removeWorktree(WID_NONEXISTENT)
    }))
  })

  it("returns windowClosed: false when no tmux window matches", async () => {
    await run(Effect.gen(function* () {
      yield* trackProject(PID_1, ProjectPath("/home/user/repo-no-win"))
      yield* trackWorktree(PID_1, BranchName("feature/no-window"), WID_6)

      const result = yield* removeWorktree(WID_6)
      expect(result.windowClosed).toBe(false)
    }))
  })

  it("kills tmux window tagged with matching worktree id", async () => {
    const killSpy = mock(() => Effect.succeed(undefined))
    await run(Effect.gen(function* () {
      yield* trackProject(PID_1, ProjectPath("/home/user/repo"))
      yield* trackWorktree(PID_1, BranchName("feature/has-window"), WID_1)

      const result = yield* removeWorktree(WID_1)
      expect(result.windowClosed).toBe(true)
      expect(killSpy).toHaveBeenCalledWith("@5")
    }), {
      tmux: { killWindow: killSpy },
      shellStdout: `@3\t\n@5\t${WID_1}\n`,
    })
  })
})
