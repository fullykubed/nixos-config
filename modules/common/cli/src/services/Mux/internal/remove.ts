import { Effect } from "effect"
import { StoreService } from "../../Store"
import type { BranchName } from "../../Git"
import { MuxStoreError } from "../errors"

export const remove = (
  projectPath: string,
  branch: BranchName,
) =>
  Effect.gen(function* () {
    const db = yield* StoreService
    yield* Effect.tryPromise({
      try: () => db.deleteFrom("mux_worktrees")
        .where("branch", "=", branch)
        .where("project_id", "in",
          db.selectFrom("mux_projects")
            .select("id")
            .where("path", "=", projectPath)
        )
        .execute(),
      catch: (e) => new MuxStoreError({
        operation: "remove",
        message: e instanceof Error ? e.message : String(e),
        project_path: projectPath,
        branch,
      }),
    })
  })
