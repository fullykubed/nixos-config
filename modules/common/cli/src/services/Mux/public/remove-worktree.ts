import { Effect } from "effect"
import { sql } from "kysely"
import { GitService } from "../../Git"
import { StoreService } from "../../Store"
import type { WorktreeId } from "../types"
import { MuxStoreError } from "../errors"
import { killWindowByWorktreeId } from "../internal/kill-window-by-worktree-id"

/**
 * Remove a worktree: delete the git worktree and branch, kill the tmux window,
 * and soft-delete the DB record.
 */
export const removeWorktree = (
  worktreeId: WorktreeId,
) =>
  Effect.gen(function* () {
    const git = yield* GitService
    const db = yield* StoreService

    // ── Look up branch and project path from DB ──────────────────
    const row = yield* Effect.tryPromise({
      try: () => db.selectFrom("mux_worktrees as w")
        .innerJoin("mux_projects as p", "p.id", "w.project_id")
        .select(["w.branch", "p.path"])
        .where("w.id", "=", worktreeId)
        .where("w.deleted_at", "is", null)
        .executeTakeFirst(),
      catch: (e) => new MuxStoreError({
        operation: "removeWorktree",
        message: e instanceof Error ? e.message : String(e),
      }),
    })

    if (row) {
      const gitCommonDir = yield* git.commonDir(row.path)

      // ── Remove git worktree ──────────────────────────────────────
      const worktrees = yield* git.worktreeList(gitCommonDir)
      const worktree = worktrees.find(w => w.branch === row.branch)
      if (worktree) {
        yield* git.worktreeRemove(worktree.path, { force: true }).pipe(
          Effect.catchAll(() => Effect.void)
        )
      }

      // ── Delete branch ────────────────────────────────────────────
      yield* git.deleteBranch(row.branch, gitCommonDir, { force: true }).pipe(
        Effect.catchAll(() => Effect.void)
      )
    }

    // ── Kill tmux window ───────────────────────────────────────────
    const windowClosed = yield* killWindowByWorktreeId(worktreeId)

    // ── Soft-delete DB record ──────────────────────────────────────
    yield* Effect.tryPromise({
      try: () => db.updateTable("mux_worktrees")
        .set({ deleted_at: sql`strftime('%Y-%m-%dT%H:%M:%fZ','now')` })
        .where("id", "=", worktreeId)
        .where("deleted_at", "is", null)
        .execute(),
      catch: (e) => new MuxStoreError({
        operation: "removeWorktree",
        message: e instanceof Error ? e.message : String(e),
      }),
    })

    return { windowClosed }
  })
