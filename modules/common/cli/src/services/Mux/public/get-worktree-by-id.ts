import { Effect, Option } from "effect"
import { StoreService } from "../../Store"
import type { WorktreeId, MuxWorktree } from "../types"
import { MuxStoreError } from "../errors"
import { resolveWorktreePath } from "../internal/resolve-worktree-path"

export const getWorktreeById = (
  worktreeId: WorktreeId,
) =>
  Effect.gen(function* () {
    const db = yield* StoreService
    const record = yield* Effect.tryPromise({
      try: () => db.selectFrom("mux_worktrees as w")
        .innerJoin("mux_projects as p", "p.id", "w.project_id")
        .select([
          "w.id as id",
          "w.project_id",
          "p.path as project_path",
          "w.branch",
          "w.created_at",
        ])
        .where("w.id", "=", worktreeId)
        .where("w.deleted_at", "is", null)
        .executeTakeFirst(),
      catch: (e) => new MuxStoreError({
        operation: "getWorktreeById",
        message: e instanceof Error ? e.message : String(e),
      }),
    })

    if (!record) return Option.none<MuxWorktree>()

    const path = yield* resolveWorktreePath(record.project_path, record.branch)
    return Option.some({ ...record, path } as MuxWorktree)
  })
