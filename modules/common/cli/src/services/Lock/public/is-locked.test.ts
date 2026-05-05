import { describe, it, expect } from "bun:test"
import { Effect, Layer } from "effect"
import { BunContext } from "@effect/platform-bun"
import { LockService, LockLive } from "../Lock"
import { StoreService, makeStoreLive } from "../../Store"

const TestStore = makeStoreLive(":memory:").pipe(Layer.provide(BunContext.layer))
const TestLock = LockLive.pipe(Layer.provide(TestStore))
const TestLayer = Layer.merge(TestStore, TestLock)

describe("LockService isLocked", () => {
  it("returns false when no lock exists", async () => {
    const result = await Effect.runPromise(
      LockService.pipe(
        Effect.flatMap((svc) => svc.isLocked("nonexistent")),
        Effect.scoped,
        Effect.provide(TestLayer)
      )
    )
    expect(result).toBe(false)
  })

  it("returns true when lock is held by a live process", async () => {
    const result = await Effect.runPromise(
      Effect.gen(function* () {
        const db = yield* StoreService
        yield* Effect.tryPromise(() =>
          db.insertInto("locks")
            .values({ name: "alive-lock", pid: process.pid })
            .execute()
        )
        const svc = yield* LockService
        return yield* svc.isLocked("alive-lock")
      }).pipe(
        Effect.scoped,
        Effect.provide(TestLayer)
      )
    )
    expect(result).toBe(true)
  })

  it("returns false when lock is held by a dead process", async () => {
    const result = await Effect.runPromise(
      Effect.gen(function* () {
        const db = yield* StoreService
        // PID 2147483647 is almost certainly not alive
        yield* Effect.tryPromise(() =>
          db.insertInto("locks")
            .values({ name: "dead-lock", pid: 2147483647 })
            .execute()
        )
        const svc = yield* LockService
        return yield* svc.isLocked("dead-lock")
      }).pipe(
        Effect.scoped,
        Effect.provide(TestLayer)
      )
    )
    expect(result).toBe(false)
  })

  it("correctly detects lock after acquire", async () => {
    const result = await Effect.runPromise(
      LockService.pipe(
        Effect.flatMap((svc) =>
          Effect.gen(function* () {
            yield* svc.acquire("check-after-acquire")
            const locked = yield* svc.isLocked("check-after-acquire")
            yield* svc.release("check-after-acquire")
            return locked
          })
        ),
        Effect.scoped,
        Effect.provide(TestLayer)
      )
    )
    expect(result).toBe(true)
  })

  it("returns false after release", async () => {
    const result = await Effect.runPromise(
      LockService.pipe(
        Effect.flatMap((svc) =>
          Effect.gen(function* () {
            yield* svc.acquire("check-after-release")
            yield* svc.release("check-after-release")
            return yield* svc.isLocked("check-after-release")
          })
        ),
        Effect.scoped,
        Effect.provide(TestLayer)
      )
    )
    expect(result).toBe(false)
  })
})
