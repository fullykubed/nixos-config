import { describe, it, expect } from "bun:test"
import { Effect } from "effect"
import { makeStoreLive } from "../../Store"
import { ProjectId, ProjectPath, BranchName } from "../../Git"
import { WorktreeId } from "../types"
import { trackProject } from "./track-project"
import { trackWorktree } from "./track-worktree"
import { find } from "../public/find"

const PID_A = ProjectId("aaaaaaaa-0000-0000-0000-000000000001")
const PID_B = ProjectId("aaaaaaaa-0000-0000-0000-000000000002")

describe("trackWorktree", () => {
  const TestStore = makeStoreLive(":memory:")
  const run = <A, E>(effect: Effect.Effect<A, E, any>) =>
    Effect.runPromise(effect.pipe(
      Effect.provide(TestStore),
    ) as Effect.Effect<A, E>)

  it("inserts a new worktree record with given id", async () => {
    const wtId = WorktreeId(crypto.randomUUID())
    await run(Effect.gen(function* () {
      yield* trackProject(PID_A, ProjectPath("/home/user/repo"))
      yield* trackWorktree(PID_A, BranchName("feature/login"), wtId)

      const record = yield* find("/home/user/repo", BranchName("feature/login"))
      expect(record).not.toBeNull()
      expect(record!.id).toBe(wtId)
      expect(record!.project_path).toBe("/home/user/repo")
      expect(record!.branch).toBe("feature/login")
    }))
  })

  it("allows reusing the same branch name for the same project", async () => {
    const id1 = WorktreeId(crypto.randomUUID())
    const id2 = WorktreeId(crypto.randomUUID())
    await run(Effect.gen(function* () {
      yield* trackProject(PID_B, ProjectPath("/home/user/repo3"))
      yield* trackWorktree(PID_B, BranchName("reused"), id1)
      yield* trackWorktree(PID_B, BranchName("reused"), id2)

      expect(id1).not.toBe(id2)
    }))
  })
})
