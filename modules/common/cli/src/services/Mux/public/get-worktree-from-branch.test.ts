import { describe, it, expect } from "bun:test"
import { Effect, Option } from "effect"
import { makeStoreLive } from "../../Store"
import { GitService, ProjectId, ProjectPath, BranchName, WorktreePath } from "../../Git"
import { WorktreeId } from "../types"
import { trackProject } from "../internal/track-project"
import { trackWorktree } from "../internal/track-worktree"
import { getWorktreeFromBranch } from "./get-worktree-from-branch"
import { stubGitService } from "../helpers.test"

const PID_1 = ProjectId("aaaaaaaa-0000-0000-0000-000000000001")
const PID_2 = ProjectId("aaaaaaaa-0000-0000-0000-000000000002")

const mockGit = stubGitService({
  worktreeList: () => Effect.succeed([
    { path: WorktreePath("/worktrees/feature/login"), head: "abc", branch: BranchName("feature/login"), isPrimary: false, bare: false, locked: false, prunable: false },
  ]),
})

describe("getWorktreeFromBranch", () => {
  const TestStore = makeStoreLive(":memory:")
  const run = <A, E>(effect: Effect.Effect<A, E, any>) =>
    Effect.runPromise(effect.pipe(
      Effect.provide(TestStore),
      Effect.provideService(GitService, mockGit),
    ) as Effect.Effect<A, E>)

  it("returns Some for an existing branch", async () => {
    const wtId = WorktreeId(crypto.randomUUID())
    const result = await run(Effect.gen(function* () {
      yield* trackProject(PID_1, ProjectPath("/home/user/repo"))
      yield* trackWorktree(PID_1, BranchName("feature/login"), wtId)

      return yield* getWorktreeFromBranch(ProjectPath("/home/user/repo"), BranchName("feature/login"))
    }))

    expect(Option.isSome(result)).toBe(true)
    const entry = Option.getOrThrow(result)
    expect(entry.id).toBe(wtId)
    expect(String(entry.project_path)).toBe("/home/user/repo")
    expect(String(entry.branch)).toBe("feature/login")
    expect(String(entry.path)).toBe("/worktrees/feature/login")
  })

  it("returns None for non-existent branch", async () => {
    const result = await run(
      getWorktreeFromBranch(ProjectPath("/no/such/repo"), BranchName("no-branch")),
    )
    expect(Option.isNone(result)).toBe(true)
  })

  it("returns None when project matches but branch does not", async () => {
    const result = await run(Effect.gen(function* () {
      yield* trackProject(PID_2, ProjectPath("/home/user/repo2"))
      yield* trackWorktree(PID_2, BranchName("existing"), WorktreeId(crypto.randomUUID()))

      return yield* getWorktreeFromBranch(ProjectPath("/home/user/repo2"), BranchName("other"))
    }))
    expect(Option.isNone(result)).toBe(true)
  })

  it("returns None when branch matches but project does not", async () => {
    const result = await run(
      getWorktreeFromBranch(ProjectPath("/different/repo"), BranchName("existing")),
    )
    expect(Option.isNone(result)).toBe(true)
  })
})
