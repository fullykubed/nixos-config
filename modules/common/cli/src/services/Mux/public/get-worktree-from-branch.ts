import { Effect, Option } from "effect"
import { StoreService } from "../../Store"
import type { BranchName, ProjectPath } from "../../Git"
import { MuxStoreError } from "../errors"
import type { MuxWorktree } from "../types"
import { resolveWorktreePath } from "../internal/resolve-worktree-path"

export const getWorktreeFromBranch = (
  projectPath: ProjectPath,
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
        operation: "getWorktreeFromBranch",
        message: e instanceof Error ? e.message : String(e),
        project_path: projectPath,
        branch,
      }),
    })

    if (!record) return Option.none<MuxWorktree>()

    const path = yield* resolveWorktreePath(projectPath, branch)
    return Option.some({ ...record, path } as MuxWorktree)
  })
