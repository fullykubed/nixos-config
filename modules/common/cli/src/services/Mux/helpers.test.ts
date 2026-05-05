import { Effect } from "effect"
import { GitService, GitCommonPath, WorktreePath, BranchName, ProjectPath } from "../Git"
import type { GitServiceShape } from "../Git"

/** Creates a GitService stub with sensible defaults, overridable per-method. */
export const stubGitService = (overrides: Partial<GitServiceShape> = {}): GitServiceShape =>
  GitService.of({
    repoRoot: () => Effect.succeed(WorktreePath("/repo")),
    commonDir: () => Effect.succeed(GitCommonPath("/repo/.git")),
    projectDir: () => Effect.succeed(ProjectPath("/repo")),
    primaryWorktreeDir: () => Effect.succeed(WorktreePath("/repo")),
    currentBranch: () => Effect.succeed(BranchName("main")),
    isWorktree: () => Effect.succeed(null),
    isDirty: () => Effect.succeed(false),
    worktreeList: () => Effect.succeed([]),
    worktreeAdd: () => Effect.succeed(WorktreePath("/repo/new-branch")),
    worktreeRemove: () => Effect.succeed(undefined),
    deleteBranch: () => Effect.succeed(undefined),
    checkout: () => Effect.succeed(undefined),
    pull: () => Effect.succeed(undefined),
    rebase: () => Effect.succeed(undefined),
    push: () => Effect.succeed(undefined),
    merge: () => Effect.succeed(undefined),
    mergeSquash: () => Effect.succeed(undefined),
    commit: () => Effect.succeed(undefined),
    getProjectConfig: () => Effect.succeed({ primary_branch: "main", worktree: { merge_strategy: "rebase" as const, files: { copy: [], link: [] }, panes: [], post_create: [], pre_merge: [] } }),
    hasRemote: () => Effect.succeed(true),
    fetch: () => Effect.succeed(undefined),
    remoteBranchExists: () => Effect.succeed(false),
    ...overrides,
  } as GitServiceShape)
