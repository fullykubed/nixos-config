import { describe, it, expect } from "bun:test"
import { Effect } from "effect"
import { makeStoreLive } from "../../Store"
import { ProjectId, ProjectPath, BranchName } from "../../Git"
import { WorktreeId } from "../types"
import { trackProject } from "../internal/track-project"
import { trackWorktree } from "../internal/track-worktree"
import { find } from "./find"

const PID_1 = ProjectId("dddddddd-0000-0000-0000-000000000001")
const PID_2 = ProjectId("dddddddd-0000-0000-0000-000000000002")
const PID_3 = ProjectId("dddddddd-0000-0000-0000-000000000003")

describe("MuxStore find", () => {
  const TestStore = makeStoreLive(":memory:")
  const run = <A, E>(effect: Effect.Effect<A, E, any>) =>
    Effect.runPromise(effect.pipe(
      Effect.provide(TestStore),
    ) as Effect.Effect<A, E>)

  it("finds an existing worktree record", async () => {
    const wtId = WorktreeId(crypto.randomUUID())
    await run(Effect.gen(function* () {
      yield* trackProject(PID_1, ProjectPath("/home/user/repo"))
      yield* trackWorktree(PID_1, BranchName("feature/search"), wtId)

      const record = yield* find("/home/user/repo", BranchName("feature/search"))
      expect(record).not.toBeNull()
      expect(record!.id).toBe(wtId)
      expect(record!.project_path).toBe("/home/user/repo")
      expect(record!.branch).toBe("feature/search")
    }))
  })

  it("returns null for non-existent record", async () => {
    await run(Effect.gen(function* () {
      const record = yield* find("/non/existent/repo", BranchName("non-existent-branch"))
      expect(record).toBeNull()
    }))
  })

  it("returns null when project_path matches but branch does not", async () => {
    await run(Effect.gen(function* () {
      yield* trackProject(PID_2, ProjectPath("/home/user/repo2"))
      yield* trackWorktree(PID_2, BranchName("existing-branch"), WorktreeId(crypto.randomUUID()))

      const record = yield* find("/home/user/repo2", BranchName("different-branch"))
      expect(record).toBeNull()
    }))
  })

  it("returns null when branch matches but project_path does not", async () => {
    await run(Effect.gen(function* () {
      yield* trackProject(PID_3, ProjectPath("/home/user/repo3"))
      yield* trackWorktree(PID_3, BranchName("shared-branch"), WorktreeId(crypto.randomUUID()))

      const record = yield* find("/different/repo", BranchName("shared-branch"))
      expect(record).toBeNull()
    }))
  })
})
