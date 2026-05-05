import { describe, it, expect } from "bun:test"
import { Effect, Option } from "effect"
import { makeStoreLive } from "../../Store"
import { AbsolutePath, GitService, ProjectId, ProjectPath, BranchName, WorktreePath, GitCommonPath, type Worktree } from "../../Git"
import { mockGetProjectConfig } from "../../Git/public/get-project-config.mock"
import { WorktreeId } from "../types"
import { trackProject } from "../internal/track-project"
import { trackWorktree } from "../internal/track-worktree"
import { getWorktreeFromPath } from "./get-worktree-from-path"

const PID = ProjectId("bbbbbbbb-0000-0000-0000-000000000001")

const makeGitService = (worktrees: readonly Worktree[], overrides: Record<string, any> = {}) => GitService.of({
  isWorktree: () => Effect.succeed(false),
  currentBranch: () => Effect.succeed(BranchName("main")),
  repoRoot: () => Effect.succeed(WorktreePath("/worktrees/feature-x")),
  worktreeList: () => Effect.succeed(worktrees),
  isDirty: () => Effect.succeed(false),
  worktreeRemove: () => Effect.succeed(undefined),
  worktreeAdd: () => Effect.succeed(WorktreePath("/repo")),
  checkout: () => Effect.succeed(undefined),
  pull: () => Effect.succeed(undefined),
  rebase: () => Effect.succeed(undefined),
  push: () => Effect.succeed(undefined),
  commonDir: () => Effect.succeed(GitCommonPath("/repo/.git")),
  projectDir: () => Effect.succeed(ProjectPath("/repo")),
  primaryWorktreeDir: () => Effect.succeed(WorktreePath("/repo")),
  deleteBranch: () => Effect.succeed(undefined),
  merge: () => Effect.succeed(undefined),
  mergeSquash: () => Effect.succeed(undefined),
  commit: () => Effect.succeed(undefined),
  getProjectConfig: mockGetProjectConfig({ projectPath: ProjectPath("/repo") }),
  hasRemote: () => Effect.succeed(true),
  fetch: () => Effect.succeed(undefined),
  remoteBranchExists: () => Effect.succeed(true),
  ...overrides,
} as any)

describe("getWorktreeFromPath", () => {
  const TestStore = makeStoreLive(":memory:")
  const run = <A, E>(effect: Effect.Effect<A, E, any>) =>
    Effect.runPromise(effect.pipe(
      Effect.provide(TestStore),
    ) as Effect.Effect<A, E>)

  it("returns Some when path matches a tracked worktree", async () => {
    const wtId = WorktreeId(crypto.randomUUID())
    const worktrees: readonly Worktree[] = [
      { path: WorktreePath("/worktrees/feature-x"), head: "abc123", branch: BranchName("feature-x"), isPrimary: false, bare: false, locked: false, prunable: false },
    ]
    const gitService = makeGitService(worktrees)

    const result = await run(Effect.gen(function* () {
      yield* trackProject(PID, ProjectPath("/repo"))
      yield* trackWorktree(PID, BranchName("feature-x"), wtId)

      return yield* getWorktreeFromPath(AbsolutePath("/worktrees/feature-x")).pipe(
        Effect.provideService(GitService, gitService),
      )
    }))

    expect(Option.isSome(result)).toBe(true)
    const entry = Option.getOrThrow(result)
    expect(entry.id).toBe(wtId)
    expect(String(entry.branch)).toBe("feature-x")
  })

  it("returns Some when path is inside a worktree subdirectory", async () => {
    const wtId = WorktreeId(crypto.randomUUID())
    const worktrees: readonly Worktree[] = [
      { path: WorktreePath("/worktrees/feature-y"), head: "abc123", branch: BranchName("feature-y"), isPrimary: false, bare: false, locked: false, prunable: false },
    ]
    const gitService = makeGitService(worktrees, {
      repoRoot: () => Effect.succeed(WorktreePath("/worktrees/feature-y")),
    })

    const result = await run(Effect.gen(function* () {
      yield* trackProject(PID, ProjectPath("/repo"))
      yield* trackWorktree(PID, BranchName("feature-y"), wtId)

      return yield* getWorktreeFromPath(AbsolutePath("/worktrees/feature-y/src/deeply/nested")).pipe(
        Effect.provideService(GitService, gitService),
      )
    }))

    expect(Option.isSome(result)).toBe(true)
    const entry = Option.getOrThrow(result)
    expect(entry.id).toBe(wtId)
  })

  it("returns None when path does not match any git worktree", async () => {
    const gitService = makeGitService([], {
      repoRoot: () => Effect.succeed(WorktreePath("/nonexistent")),
    })

    const result = await run(
      getWorktreeFromPath(AbsolutePath("/nonexistent")).pipe(
        Effect.provideService(GitService, gitService),
      ),
    )
    expect(Option.isNone(result)).toBe(true)
  })

  it("returns None when path matches git worktree but not tracked in DB", async () => {
    const worktrees: readonly Worktree[] = [
      { path: WorktreePath("/worktrees/untracked-wt"), head: "def456", branch: BranchName("untracked"), isPrimary: false, bare: false, locked: false, prunable: false },
    ]
    const gitService = makeGitService(worktrees, {
      repoRoot: () => Effect.succeed(WorktreePath("/worktrees/untracked-wt")),
    })

    const result = await run(
      getWorktreeFromPath(AbsolutePath("/worktrees/untracked-wt")).pipe(
        Effect.provideService(GitService, gitService),
      ),
    )
    expect(Option.isNone(result)).toBe(true)
  })
})
