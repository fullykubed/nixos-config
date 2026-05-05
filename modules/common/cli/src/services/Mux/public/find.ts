import { Effect } from "effect"
import { StoreService } from "../../Store"
import type { BranchName } from "../../Git"
import { MuxStoreError } from "../errors"

export const find = (
  projectPath: string,
  branch: BranchName,
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
        .where("p.path", "=", projectPath)
        .where("w.branch", "=", branch)
        .where("w.deleted_at", "is", null)
        .executeTakeFirst(),
      catch: (e) => new MuxStoreError({
        operation: "find",
        message: e instanceof Error ? e.message : String(e),
        project_path: projectPath,
        branch,
      }),
    })

    if (!record) {
      return null
    }

    return {
      id: record.id,
      project_id: record.project_id,
      project_path: record.project_path,
      branch: record.branch,
      created_at: record.created_at,
    }
  })
