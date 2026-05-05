import { Context, Effect, Layer } from "effect"
import { FileSystem, Path } from "@effect/platform"
import { mkContextInjector } from "../../lib/mkContextInjector"
import { ShellService } from "../Shell"
import { TmuxService } from "../Tmux"
import { GitService } from "../Git"
import { StoreService } from "../Store"
import { createWorktree } from "./public/create-worktree"
import { trackWorktree } from "./internal/track-worktree"
import { getWorktreeById } from "./public/get-worktree-by-id"
import { getWorktreeFromBranch } from "./public/get-worktree-from-branch"
import { getWorktreeFromPath } from "./public/get-worktree-from-path"
import { removeWorktree } from "./public/remove-worktree"

// ── Re-exports ───────────────────────────────────────────────────────

export type { MuxWorktree } from "./types"
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
  const inject = mkContextInjector(ctx, "Mux")

  return {
    createWorktree: inject(createWorktree),
    trackWorktree: inject(trackWorktree),
    getWorktreeById: inject(getWorktreeById),
    getWorktreeFromBranch: inject(getWorktreeFromBranch),
    getWorktreeFromPath: inject(getWorktreeFromPath),
    removeWorktree: inject(removeWorktree),
  }
})

export type MuxServiceShape = Effect.Effect.Success<typeof make>

export class MuxService extends Context.Tag("MuxService")<
  MuxService,
  MuxServiceShape
>() {}

export const MuxLive = Layer.effect(MuxService, make)
