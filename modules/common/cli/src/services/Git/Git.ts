import { Context, Effect, Layer } from "effect"
import { FileSystem, Path } from "@effect/platform"
import { ShellService } from "../Shell"
import { mkContextInjector } from "../../lib/mkContextInjector"
import { AbsolutePath } from "../../lib/types/absolute-path"
import { ProjectPath, GitCommonPath, WorktreePath, BranchName, ProjectId } from "./types"
import { repoRoot } from "./public/repo-root"
import { commonDir } from "./public/common-dir"
import { currentBranch } from "./public/current-branch"
import { isWorktree } from "./public/is-worktree"
import { isDirty } from "./public/is-dirty"
import { worktreeList } from "./public/worktree-list"
import { worktreeAdd } from "./public/worktree-add"
import { worktreeRemove } from "./public/worktree-remove"
import { checkout } from "./public/checkout"
import { pull } from "./public/pull"
import { rebase } from "./public/rebase"
import { push } from "./public/push"
import { merge } from "./public/merge"
import { mergeSquash } from "./public/merge-squash"
import { commit } from "./public/commit"
import { getProjectConfig } from "./public/get-project-config"
import { hasRemote } from "./public/has-remote"
import { fetch } from "./public/fetch"
import { remoteBranchExists } from "./public/remote-branch-exists"
import { deleteBranch } from "./public/delete-branch"
import { projectDir } from "./public/get-project-dir"
import { primaryWorktreeDir } from "./public/primary-worktree-dir"

// ── Re-exports ───────────────────────────────────────────────────────

export type { Worktree } from "./types"
export { ProjectPath, GitCommonPath, WorktreePath, AbsolutePath, BranchName, ProjectId }

// ── Service ──────────────────────────────────────────────────────────

const make = Effect.gen(function* () {
  const shell = yield* ShellService
  const fs = yield* FileSystem.FileSystem
  const path = yield* Path.Path

  const ctx = Context.empty().pipe(
    Context.add(ShellService, shell),
    Context.add(FileSystem.FileSystem, fs),
    Context.add(Path.Path, path),
  )
  const inject = mkContextInjector(ctx, "Git")

  return {
    repoRoot: inject(repoRoot),
    commonDir: inject(commonDir),
    projectDir: inject(projectDir),
    primaryWorktreeDir: inject(primaryWorktreeDir),
    currentBranch: inject(currentBranch),
    isWorktree: inject(isWorktree),
    isDirty: inject(isDirty),
    worktreeList: inject(worktreeList),
    worktreeAdd: inject(worktreeAdd),
    worktreeRemove: inject(worktreeRemove),
    deleteBranch: inject(deleteBranch),
    checkout: inject(checkout),
    pull: inject(pull),
    rebase: inject(rebase),
    push: inject(push),
    merge: inject(merge),
    mergeSquash: inject(mergeSquash),
    commit: inject(commit),
    getProjectConfig: inject(getProjectConfig),
    hasRemote: inject(hasRemote),
    fetch: inject(fetch),
    remoteBranchExists: inject(remoteBranchExists),
  }
})

export type GitServiceShape = Effect.Effect.Success<typeof make>

export class GitService extends Context.Tag("GitService")<
  GitService,
  GitServiceShape
>() {}

export const GitLive = Layer.effect(GitService, make)
