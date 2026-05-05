import { describe, it, expect } from "bun:test"
import { Effect } from "effect"
import { makeStoreLive } from "../../Store"
import { ProjectId, ProjectPath, BranchName } from "../../Git"
import { WorktreeId } from "../types"
import { trackProject } from "../internal/track-project"
import { trackWorktree } from "../internal/track-worktree"
import { listAll } from "./list-all"

const PID_1 = ProjectId("eeeeeeee-0000-0000-0000-000000000001")
const PID_2 = ProjectId("eeeeeeee-0000-0000-0000-000000000002")

describe("MuxStore listAll", () => {
  const TestStore = makeStoreLive(":memory:")
  const run = <A, E>(effect: Effect.Effect<A, E, any>) =>
    Effect.runPromise(effect.pipe(
      Effect.provide(TestStore),
    ) as Effect.Effect<A, E>)

  it("lists all worktree records across projects", async () => {
    await run(Effect.gen(function* () {
      yield* trackProject(PID_1, ProjectPath("/home/user/repo1"))
      yield* trackProject(PID_2, ProjectPath("/home/user/repo2"))
      yield* trackWorktree(PID_1, BranchName("feature/a"), WorktreeId(crypto.randomUUID()))
      yield* trackWorktree(PID_2, BranchName("feature/b"), WorktreeId(crypto.randomUUID()))
      yield* trackWorktree(PID_1, BranchName("feature/c"), WorktreeId(crypto.randomUUID()))

      const allRecords = yield* listAll()
      expect(allRecords).toHaveLength(3)

      const paths = allRecords.map(r => r.project_path)
      expect(paths).toContain("/home/user/repo1")
      expect(paths).toContain("/home/user/repo2")

      const branches = allRecords.map(r => r.branch)
      expect(branches).toContain("feature/a")
      expect(branches).toContain("feature/b")
      expect(branches).toContain("feature/c")

      // All records should have a string id
      for (const record of allRecords) {
        expect(typeof record.id).toBe("string")
      }
    }))
  })

  it("returns empty array when no worktrees exist", async () => {
    await run(Effect.gen(function* () {
      const records = yield* listAll()
      expect(records).toHaveLength(0)
    }))
  })

  it("orders records by project path, then by branch", async () => {
    await run(Effect.gen(function* () {
      yield* trackProject(PID_1, ProjectPath("/home/user/zzz-repo"))
      yield* trackProject(PID_2, ProjectPath("/home/user/aaa-repo"))
      yield* trackWorktree(PID_1, BranchName("first-zzz"), WorktreeId(crypto.randomUUID()))
      yield* trackWorktree(PID_2, BranchName("second-aaa"), WorktreeId(crypto.randomUUID()))
      yield* trackWorktree(PID_2, BranchName("first-aaa"), WorktreeId(crypto.randomUUID()))

      const records = yield* listAll()
      expect(records).toHaveLength(3)

      // Should be ordered by project path first (aaa before zzz), then branch
      expect(records[0]!.project_path).toBe("/home/user/aaa-repo")
      expect(records[0]!.branch).toBe("first-aaa")
      expect(records[1]!.project_path).toBe("/home/user/aaa-repo")
      expect(records[1]!.branch).toBe("second-aaa")
      expect(records[2]!.project_path).toBe("/home/user/zzz-repo")
      expect(records[2]!.branch).toBe("first-zzz")
    }))
  })
})
