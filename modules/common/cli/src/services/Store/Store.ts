import { Context, Effect, Layer } from "effect"
import { FileSystem, Path } from "@effect/platform"
import { Database } from "bun:sqlite"
import { Kysely, Migrator } from "kysely"
import { BunSqliteDialect } from "kysely-bun-sqlite"
import { homedir } from "node:os"
import type { DB } from "./types"
import { StoreError } from "./errors"
import { migrationProvider } from "./migration-provider"

export { StoreError } from "./errors"
export type { DB,   } from "./types"

export class StoreService extends Context.Tag("StoreService")<
  StoreService,
  Kysely<DB>
>() {}

export const makeStoreLive = (dbPath: string): Layer.Layer<StoreService, StoreError, Path.Path | FileSystem.FileSystem> =>
  Layer.scoped(
    StoreService,
    Effect.gen(function* () {
      if (dbPath !== ":memory:") {
        const path = yield* Path.Path
        const fs = yield* FileSystem.FileSystem
        yield* fs.makeDirectory(path.dirname(dbPath), { recursive: true }).pipe(
          Effect.catchAll((e) => Effect.fail(new StoreError({
            operation: "mkdir",
            message: String(e),
            path: dbPath,
          })))
        )
      }
      return yield* Effect.acquireRelease(
        Effect.gen(function* () {
          const rawDb = yield* Effect.try({
            try: () => {
              const db = new Database(dbPath)
              db.run("PRAGMA journal_mode = WAL")
              db.run("PRAGMA busy_timeout = 5000")
              db.run("PRAGMA foreign_keys = ON")
              return db
            },
            catch: (e) => new StoreError({
              operation: "open",
              message: e instanceof Error ? e.message : String(e),
              path: dbPath,
            }),
          })
          const kyselyDb = new Kysely<DB>({
            dialect: new BunSqliteDialect({ database: rawDb }),
          })
          const { error } = yield* Effect.tryPromise({
            try: () => new Migrator({ db: kyselyDb, provider: migrationProvider }).migrateToLatest(),
            catch: (e) => new StoreError({
              operation: "migrate",
              message: e instanceof Error ? e.message : String(e),
              path: dbPath,
            }),
          })
          if (error) {
            return yield* Effect.fail(new StoreError({
              operation: "migrate",
              message: error instanceof Error ? error.message : JSON.stringify(error),
              path: dbPath,
            }))
          }
          return kyselyDb
        }),
        (db) => Effect.promise(() => db.destroy())
      )
    })
  )

export const StoreLive: Layer.Layer<StoreService, StoreError, Path.Path | FileSystem.FileSystem> = Layer.unwrapEffect(
  Effect.gen(function* () {
    const path = yield* Path.Path
    const stateHome = process.env.XDG_STATE_HOME ?? path.join(homedir(), ".local", "state")
    const dbPath = path.join(stateHome, "j", "cli.db")
    return makeStoreLive(dbPath)
  })
)
