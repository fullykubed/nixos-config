import { describe, it, expect } from "bun:test"
import { Effect } from "effect"
import { makeStoreLive } from "../../Store"
import { ProjectId, ProjectPath, BranchName } from "../../Git"
import { WorktreeId } from "../types"
import { trackProject } from "./track-project"
import { trackWorktree } from "./track-worktree"
import { find } from "../public/find"
import { remove } from "./remove"
import { listAll } from "../public/list-all"

const PID_1 = ProjectId("bbbbbbbb-0000-0000-0000-000000000001")
const PID_2 = ProjectId("bbbbbbbb-0000-0000-0000-000000000002")
const PID_3 = ProjectId("bbbbbbbb-0000-0000-0000-000000000003")

describe("MuxStore remove", () => {
  const TestStore = makeStoreLive(":memory:")
  const run = <A, E>(effect: Effect.Effect<A, E, any>) =>
    Effect.runPromise(effect.pipe(
      Effect.provide(TestStore),
    ) as Effect.Effect<A, E>)

  it("removes an existing worktree record", async () => {
    await run(Effect.gen(function* () {
      yield* trackProject(PID_1, ProjectPath("/home/user/repo"))
      yield* trackWorktree(PID_1, BranchName("feature/remove-test"), WorktreeId(crypto.randomUUID()))

      let record = yield* find("/home/user/repo", BranchName("feature/remove-test"))
      expect(record).not.toBeNull()

      yield* remove("/home/user/repo", BranchName("feature/remove-test"))

      record = yield* find("/home/user/repo", BranchName("feature/remove-test"))
      expect(record).toBeNull()
    }))
  })

  it("removes only the specified record", async () => {
    await run(Effect.gen(function* () {
      yield* trackProject(PID_2, ProjectPath("/home/user/repo2"))
      yield* trackProject(PID_3, ProjectPath("/home/user/other-repo"))
      yield* trackWorktree(PID_2, BranchName("feature/keep"), WorktreeId(crypto.randomUUID()))
      yield* trackWorktree(PID_2, BranchName("feature/remove"), WorktreeId(crypto.randomUUID()))
      yield* trackWorktree(PID_3, BranchName("feature/keep-other"), WorktreeId(crypto.randomUUID()))

      let allRecords = yield* listAll()
      expect(allRecords).toHaveLength(3)

      yield* remove("/home/user/repo2", BranchName("feature/remove"))

      allRecords = yield* listAll()
      expect(allRecords).toHaveLength(2)

      const remainingBranches = allRecords.map(r => r.branch)
      expect(remainingBranches).toContain("feature/keep")
      expect(remainingBranches).toContain("feature/keep-other")
      expect(remainingBranches).not.toContain("feature/remove")
    }))
  })

  it("silently succeeds when removing non-existent record", async () => {
    await run(Effect.gen(function* () {
      yield* remove("/non/existent/repo", BranchName("non-existent-branch"))

      const allRecords = yield* listAll()
      expect(allRecords).toHaveLength(0)
    }))
  })

  it("requires both project_path and branch to match for removal", async () => {
    await run(Effect.gen(function* () {
      yield* trackProject(PID_1, ProjectPath("/home/user/repo3"))
      yield* trackWorktree(PID_1, BranchName("shared-branch"), WorktreeId(crypto.randomUUID()))

      yield* remove("/different/repo", BranchName("shared-branch"))

      const record = yield* find("/home/user/repo3", BranchName("shared-branch"))
      expect(record).not.toBeNull()

      yield* remove("/home/user/repo3", BranchName("different-branch"))

      const stillExists = yield* find("/home/user/repo3", BranchName("shared-branch"))
      expect(stillExists).not.toBeNull()
    }))
  })
})
