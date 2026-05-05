import { describe, it, expect } from "bun:test"
import { Effect } from "effect"
import { makeStoreLive } from "../../Store"
import { ProjectId, ProjectPath, BranchName } from "../../Git"
import { WorktreeId } from "../types"
import { trackProject } from "../internal/track-project"
import { trackWorktree } from "../internal/track-worktree"
import { listByProject } from "./list-by-project"

const PID_1 = ProjectId("ffffffff-0000-0000-0000-000000000001")
const PID_2 = ProjectId("ffffffff-0000-0000-0000-000000000002")
const PID_3 = ProjectId("ffffffff-0000-0000-0000-000000000003")

describe("MuxStore listByProject", () => {
  const TestStore = makeStoreLive(":memory:")
  const run = <A, E>(effect: Effect.Effect<A, E, any>) =>
    Effect.runPromise(effect.pipe(
      Effect.provide(TestStore),
    ) as Effect.Effect<A, E>)

  it("lists worktrees for a specific project", async () => {
    await run(Effect.gen(function* () {
      yield* trackProject(PID_1, ProjectPath("/home/user/repo1"))
      yield* trackProject(PID_2, ProjectPath("/home/user/repo2"))
      yield* trackWorktree(PID_1, BranchName("feature/a"), WorktreeId(crypto.randomUUID()))
      yield* trackWorktree(PID_1, BranchName("feature/b"), WorktreeId(crypto.randomUUID()))
      yield* trackWorktree(PID_2, BranchName("feature/c"), WorktreeId(crypto.randomUUID()))

      const repo1Records = yield* listByProject("/home/user/repo1")
      expect(repo1Records).toHaveLength(2)
      expect(repo1Records.map(r => r.branch)).toEqual(["feature/a", "feature/b"])
      expect(repo1Records.every(r => r.project_path === "/home/user/repo1")).toBe(true)

      const repo2Records = yield* listByProject("/home/user/repo2")
      expect(repo2Records).toHaveLength(1)
      expect(repo2Records[0]!.branch).toBe("feature/c")
    }))
  })

  it("returns empty array for project with no worktrees", async () => {
    await run(Effect.gen(function* () {
      const records = yield* listByProject("/non/existent/repo")
      expect(records).toHaveLength(0)
    }))
  })

  it("orders records by branch ascending", async () => {
    await run(Effect.gen(function* () {
      yield* trackProject(PID_3, ProjectPath("/home/user/repo"))
      yield* trackWorktree(PID_3, BranchName("charlie"), WorktreeId(crypto.randomUUID()))
      yield* trackWorktree(PID_3, BranchName("alpha"), WorktreeId(crypto.randomUUID()))
      yield* trackWorktree(PID_3, BranchName("bravo"), WorktreeId(crypto.randomUUID()))

      const records = yield* listByProject("/home/user/repo")
      expect(records).toHaveLength(3)
      expect(records[0]!.branch).toBe("alpha")
      expect(records[1]!.branch).toBe("bravo")
      expect(records[2]!.branch).toBe("charlie")
    }))
  })
})
