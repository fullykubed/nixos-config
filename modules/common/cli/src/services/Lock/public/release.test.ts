import { describe, it, expect } from "bun:test"
import { Effect, Layer } from "effect"
import { BunContext } from "@effect/platform-bun"
import { LockService, LockLive } from "../Lock"
import { StoreService, makeStoreLive } from "../../Store"

const TestStore = makeStoreLive(":memory:").pipe(Layer.provide(BunContext.layer))
const TestLock = LockLive.pipe(Layer.provide(TestStore))
const TestLayer = Layer.merge(TestStore, TestLock)

describe("LockService release", () => {
  it("releases an acquired lock", async () => {
    await Effect.runPromise(
      LockService.pipe(
        Effect.flatMap((svc) =>
          Effect.gen(function* () {
            yield* svc.acquire("release-test")
            yield* svc.release("release-test")
            // Verify lock is gone by acquiring again
            yield* svc.acquire("release-test")
            yield* svc.release("release-test")
          })
        ),
        Effect.scoped,
        Effect.provide(TestLayer)
      )
    )
  })

  it("is idempotent — releasing a non-existent lock does not fail", async () => {
    await Effect.runPromise(
      LockService.pipe(
        Effect.flatMap((svc) => svc.release("never-acquired")),
        Effect.scoped,
        Effect.provide(TestLayer)
      )
    )
  })

  it("is idempotent — double release does not fail", async () => {
    await Effect.runPromise(
      LockService.pipe(
        Effect.flatMap((svc) =>
          Effect.gen(function* () {
            yield* svc.acquire("double-release")
            yield* svc.release("double-release")
            yield* svc.release("double-release")
          })
        ),
        Effect.scoped,
        Effect.provide(TestLayer)
      )
    )
  })

  it("removes the lock row from the database", async () => {
    const remainingLocks = await Effect.runPromise(
      Effect.gen(function* () {
        const svc = yield* LockService
        const db = yield* StoreService
        yield* svc.acquire("db-check")
        yield* svc.release("db-check")
        return yield* Effect.tryPromise(() =>
          db.selectFrom("locks")
            .where("name", "=", "db-check")
            .selectAll()
            .execute()
        )
      }).pipe(
        Effect.scoped,
        Effect.provide(TestLayer)
      )
    )
    expect(remainingLocks).toHaveLength(0)
  })

  it("only releases the specified lock", async () => {
    await Effect.runPromise(
      Effect.gen(function* () {
        const svc = yield* LockService
        yield* svc.acquire("lock-a")
        yield* svc.acquire("lock-b")
        yield* svc.release("lock-a")
        // lock-b should still be locked
        const bLocked = yield* svc.isLocked("lock-b")
        expect(bLocked).toBe(true)
        yield* svc.release("lock-b")
      }).pipe(
        Effect.scoped,
        Effect.provide(TestLayer)
      )
    )
  })
})
