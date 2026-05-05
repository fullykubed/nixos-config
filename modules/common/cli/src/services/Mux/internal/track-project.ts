import { Effect } from "effect"
import { StoreService } from "../../Store"
import type { ProjectId, ProjectPath } from "../../Git"
import { MuxStoreError } from "../errors"

/**
 * Upsert a project into the store. If a row with the given id exists,
 * updates its path. Otherwise inserts a new row.
 */
export const trackProject = (projectId: ProjectId, path: ProjectPath) =>
  Effect.gen(function* () {
    const db = yield* StoreService

    const existing = yield* Effect.tryPromise({
      try: () => db.selectFrom("mux_projects")
        .select("id")
        .where("id", "=", projectId)
        .executeTakeFirst(),
      catch: (e) => new MuxStoreError({
        operation: "trackProject",
        message: e instanceof Error ? e.message : String(e),
        project_path: path,
      }),
    })

    if (existing) {
      yield* Effect.tryPromise({
        try: () => db.updateTable("mux_projects")
          .set({ path })
          .where("id", "=", projectId)
          .execute(),
        catch: (e) => new MuxStoreError({
          operation: "trackProject",
          message: e instanceof Error ? e.message : String(e),
          project_path: path,
        }),
      })
    } else {
      yield* Effect.tryPromise({
        try: () => db.insertInto("mux_projects")
          .values({ id: projectId, path })
          .execute(),
        catch: (e) => new MuxStoreError({
          operation: "trackProject",
          message: e instanceof Error ? e.message : String(e),
          project_path: path,
        }),
      })
    }
  })
