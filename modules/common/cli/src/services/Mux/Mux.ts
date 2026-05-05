import { Context, Effect, Layer } from "effect"
import { FileSystem, Path } from "@effect/platform"
import { mkContextInjector } from "../../lib/mkContextInjector"
import { ShellService } from "../Shell"
import { TmuxService } from "../Tmux"
import { GitService, ProjectPath, type BranchName } from "../Git"
import { StoreService } from "../Store"
import { createWorktree } from "./public/create-worktree"
import { trackWorktree } from "./internal/track-worktree"
import { find } from "./public/find"
import { listAll } from "./public/list-all"
import { listByProject } from "./public/list-by-project"
import { removeWorktree } from "./public/remove-worktree"

// ── Re-exports ───────────────────────────────────────────────────────

export type { MuxWorktreeEntry } from "./types"
export { WorktreeId } from "./types"
export { MuxStoreError, MuxProjectNotFoundError, MuxTmuxSyncError, MuxBranchExistsOnRemoteError, MuxBranchExistsLocallyError, MuxWorktreePathConflictError, MuxCreateWorktreeError } from "./errors"

// ── Service ──────────────────────────────────────────────────────────

const make = Effect.gen(function* () {
  const shell = yield* ShellService
  const tmux = yield* TmuxService
  const git = yield* GitService
  const store = yield* StoreService
  const fs = yield* FileSystem.FileSystem
  const path = yield* Path.Path

  const ctx = Context.empty().pipe(
    Context.add(ShellService, shell),
    Context.add(TmuxService, tmux),
    Context.add(GitService, git),
    Context.add(StoreService, store),
    Context.add(FileSystem.FileSystem, fs),
    Context.add(Path.Path, path),
  )
  const inject = mkContextInjector(ctx)
  const provide = Effect.provide(ctx)

  return {
    createWorktree: inject(createWorktree),
    trackWorktree: inject(trackWorktree),
    find: (projectPath: string, branch: BranchName) => provide(find(projectPath, branch)),
    listAll: inject(listAll),
    listByProject: (projectPath: string) => provide(listByProject(ProjectPath(projectPath))),
    removeWorktree: inject(removeWorktree),
  }
})

export type MuxServiceShape = Effect.Effect.Success<typeof make>

export class MuxService extends Context.Tag("MuxService")<
  MuxService,
  MuxServiceShape
>() {}

export const MuxLive = Layer.effect(MuxService, make)
