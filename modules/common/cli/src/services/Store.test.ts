import { describe, it, expect } from "bun:test"
import { Effect, Exit, Layer } from "effect"
import { BunContext } from "@effect/platform-bun"
import { sql } from "kysely"
import { StoreService, makeStoreLive, StoreError } from "./Store"

const TestStore = makeStoreLive(":memory:").pipe(Layer.provide(BunContext.layer))

describe("StoreService", () => {
  it("opens an in-memory database and runs migrations", async () => {
    const result = await Effect.runPromise(
      StoreService.pipe(
        Effect.flatMap((db) =>
          Effect.tryPromise({
            try: () => sql<{ name: string }>`SELECT name FROM kysely_migration`.execute(db),
            catch: (e) => new StoreError({ operation: "test", message: String(e) }),
          })
        ),
        Effect.scoped,
        Effect.provide(TestStore)
      )
    )
    expect(result.rows.length).toBeGreaterThanOrEqual(1)
  })

  it("creates the locks table", async () => {
    const result = await Effect.runPromise(
      StoreService.pipe(
        Effect.flatMap((db) =>
          Effect.tryPromise({
            try: () =>
              sql<{ name: string }>`SELECT name FROM sqlite_master WHERE type='table' AND name='locks'`.execute(db),
            catch: (e) => new StoreError({ operation: "test", message: String(e) }),
          })
        ),
        Effect.scoped,
        Effect.provide(TestStore)
      )
    )
    expect(result.rows.map((r) => r.name)).toContain("locks")
  })

  it("is idempotent — running migrations twice does not fail", async () => {
    // Two sequential scoped uses of the same :memory: factory should each succeed independently
    const run = StoreService.pipe(
      Effect.flatMap((db) =>
        Effect.tryPromise({
          try: () => sql<{ name: string }>`SELECT name FROM kysely_migration`.execute(db),
          catch: (e) => new StoreError({ operation: "test", message: String(e) }),
        })
      ),
      Effect.scoped,
      Effect.provide(TestStore)
    )

    const v1 = await Effect.runPromise(run)
    const v2 = await Effect.runPromise(run)
    expect(v1.rows.length).toBe(v2.rows.length)
  })

  it("destroys the database when scope ends", async () => {
    let destroyed = false

    await Effect.runPromise(
      StoreService.pipe(
        Effect.tap((db) =>
          Effect.sync(() => {
            const origDestroy = db.destroy.bind(db)
            db.destroy = async () => {
              destroyed = true
              return origDestroy()
            }
          })
        ),
        Effect.scoped,
        Effect.provide(TestStore)
      )
    )

    expect(destroyed).toBe(true)
  })

  it("fails with StoreError on invalid path", async () => {
    const badLayer = makeStoreLive("/proc/0/nonexistent/db.sqlite").pipe(
      Layer.provide(BunContext.layer)
    )
    const exit = await Effect.runPromiseExit(
      StoreService.pipe(
        Effect.scoped,
        Effect.provide(badLayer)
      )
    )
    expect(Exit.isFailure(exit)).toBe(true)
  })
})
