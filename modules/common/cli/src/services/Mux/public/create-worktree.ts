import { Effect, Exit, Ref, pipe } from "effect"
import { GitService, type ProjectPath, type BranchName } from "../../Git"
import { TmuxService } from "../../Tmux"
import { StoreService } from "../../Store"
import { MuxBranchExistsOnRemoteError, MuxBranchExistsLocallyError, MuxWorktreePathConflictError, MuxCreateWorktreeError, MuxStoreError } from "../errors"
import { WorktreeId } from "../types"
import { initWorktree } from "../internal/init-worktree"
import { trackProject } from "../internal/track-project"
import { trackWorktree } from "../internal/track-worktree"
import { createSession } from "../internal/create-session"
import { createWindow } from "../internal/create-window"

/**
 * Create a new git worktree and open it in a tmux window.
 * Registers the worktree in the DB and cleans up on failure.
 */
export const createWorktree = (
  projectPath: ProjectPath,
  branch: BranchName,
) =>
  Effect.gen(function* () {
    const git = yield* GitService

    const config = yield* git.getProjectConfig(projectPath)
    const gitCommonDir = config.gitCommonDir

    // 1. Check for remote conflicts (remoteBranchExists auto-fetches)
    const remoteExists = yield* git.remoteBranchExists("origin", branch, gitCommonDir)
    if (remoteExists) {
      yield* Effect.fail(new MuxBranchExistsOnRemoteError({ branch }))
    }

    // 2. Create worktree (new branch)
    const worktreePath = yield* git.worktreeAdd(branch, gitCommonDir, { create: true }).pipe(
      Effect.catchAll((gitErr) =>
        Effect.gen(function* () {
          // Check full stderr (via cause) since the message field only has the first line
          const stderr = gitErr._tag === "GitUnknownError" ? (gitErr.cause?.stderr ?? gitErr.message) : ""

          if (stderr.includes("already exists and is not empty")) {
            return yield* Effect.fail(new MuxWorktreePathConflictError({
              path: branch,
              cause: gitErr,
            }))
          }

          if (stderr.includes("already exists")) {
            const worktrees = yield* git.worktreeList(gitCommonDir)
            const hasWorktree = worktrees.some(wt => wt.branch && wt.branch === branch)
            return yield* Effect.fail(new MuxBranchExistsLocallyError({
              branch,
              hasWorktree,
              cause: gitErr,
            }))
          }
          return yield* Effect.fail(gitErr)
        })
      )
    )

    // 3. Initialize worktree, open window, record in DB (with cleanup on failure/interruption)
    const worktreeId = WorktreeId(crypto.randomUUID())
    const windowIdRef = yield* Ref.make<string | null>(null)

    const cleanup = Effect.uninterruptible(
      Effect.gen(function* () {
        const git = yield* GitService
        const tmux = yield* TmuxService
        const db = yield* StoreService
        const windowId = yield* Ref.get(windowIdRef)

        if (windowId !== null) {
          yield* tmux.killWindow(windowId).pipe(Effect.catchAll(() => Effect.void))
        }
        yield* git.worktreeRemove(worktreePath, { force: true }).pipe(Effect.catchAll(() => Effect.void))
        yield* git.deleteBranch(branch, gitCommonDir, { force: true }).pipe(Effect.catchAll(() => Effect.void))
        yield* Effect.tryPromise({
          try: () => db.deleteFrom("mux_worktrees")
            .where("id", "=", worktreeId)
            .execute(),
          catch: (e) => new MuxStoreError({
            operation: "createWorktree:cleanup",
            message: e instanceof Error ? e.message : String(e),
            branch,
          }),
        }).pipe(Effect.catchAll(() => Effect.void))
      })
    )

    yield* pipe(
      Effect.gen(function* () {
        // Phase 1: parallel setup (init worktree, create session, track project)
        yield* Effect.all([
          initWorktree(worktreePath),
          createSession(config.tmux_session, config.projectId),
          trackProject(config.projectId, config.projectPath),
        ], { concurrency: "unbounded" })

        // Phase 2: create window (sets ref so cleanup can find it)
        yield* createWindow(branch, worktreePath, config.worktree.panes, worktreeId).pipe(
          Effect.tap((winId) => Ref.set(windowIdRef, winId)),
        )

        // Phase 3: record worktree in DB
        yield* trackWorktree(config.projectId, branch, worktreeId)
      }),
      Effect.onExit((exit) =>
        Exit.isSuccess(exit) ? Effect.void : cleanup
      ),
      Effect.catchAll((error) =>
        Effect.fail(new MuxCreateWorktreeError({ branch, cause: error }))
      )
    )
  })
