import { describe, it, expect } from "bun:test"
import { Effect, Option } from "effect"
import { makeStoreLive } from "../../Store"
import { GitService, ProjectId, ProjectPath, BranchName, WorktreePath } from "../../Git"
import { WorktreeId } from "../types"
import { trackProject } from "../internal/track-project"
import { trackWorktree } from "../internal/track-worktree"
import { getWorktreeById } from "./get-worktree-by-id"
import { stubGitService } from "../helpers.test"

const PID = ProjectId("cccccccc-0000-0000-0000-000000000001")

const mockGit = stubGitService({
  worktreeList: () => Effect.succeed([
    { path: WorktreePath("/worktrees/feature/search"), head: "abc", branch: BranchName("feature/search"), isPrimary: false, bare: false, locked: false, prunable: false },
  ]),
})

describe("getWorktreeById", () => {
  const TestStore = makeStoreLive(":memory:")
  const run = <A, E>(effect: Effect.Effect<A, E, any>) =>
    Effect.runPromise(effect.pipe(
      Effect.provide(TestStore),
      Effect.provideService(GitService, mockGit),
    ) as Effect.Effect<A, E>)

  it("returns Some for a valid id", async () => {
    const wtId = WorktreeId(crypto.randomUUID())
    const result = await run(Effect.gen(function* () {
      yield* trackProject(PID, ProjectPath("/home/user/repo"))
      yield* trackWorktree(PID, BranchName("feature/search"), wtId)

      return yield* getWorktreeById(wtId)
    }))

    expect(Option.isSome(result)).toBe(true)
    const entry = Option.getOrThrow(result)
    expect(entry.id).toBe(wtId)
    expect(String(entry.project_path)).toBe("/home/user/repo")
    expect(String(entry.branch)).toBe("feature/search")
    expect(String(entry.path)).toBe("/worktrees/feature/search")
  })

  it("returns None for non-existent id", async () => {
    const fakeId = WorktreeId("00000000-0000-0000-0000-ffffffffffff")
    const result = await run(getWorktreeById(fakeId))
    expect(Option.isNone(result)).toBe(true)
  })
})
