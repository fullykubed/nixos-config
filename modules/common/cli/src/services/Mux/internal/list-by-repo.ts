import { Effect } from "effect"
import { StoreService } from "../../Store"
import { MuxStoreError } from "../errors"
import type {} from "../types"

export const listByRepo = (
  repo_root: string,
) =>
  Effect.gen(function* () {
    const db = yield* StoreService
    const records = yield* Effect.tryPromise({
      try: () => db.selectFrom("mux_worktrees as w")
        .innerJoin("mux_projects as p", "p.id", "w.project_id")
        .select([
          "w.id as id",
          "w.project_id",
          "p.path as project_path",
          "w.branch",
          "w.created_at",
        ])
        .where("p.path", "=", repo_root)
        .where("w.deleted_at", "is", null)
        .orderBy("w.created_at", "asc")
        .execute(),
      catch: (e) => new MuxStoreError({
        operation: "listByRepo",
        message: e instanceof Error ? e.message : String(e),
        project_path: repo_root,
      }),
    })

    return records.map((record) => ({
      id: record.id,
      project_id: record.project_id,
      project_path: record.project_path,
      branch: record.branch,
      created_at: record.created_at,
    }))
  })
