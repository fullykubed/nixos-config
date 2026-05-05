import { describe, it, expect } from "bun:test"
import { Effect, Exit, Layer } from "effect"
import { BunContext } from "@effect/platform-bun"
import { LockService, LockLive } from "../Lock"
import { StoreService, makeStoreLive } from "../../Store"

const TestStore = makeStoreLive(":memory:").pipe(Layer.provide(BunContext.layer))
const TestLock = LockLive.pipe(Layer.provide(TestStore))
const TestLayer = Layer.merge(TestStore, TestLock)

function extractFailureTag(exit: Exit.Exit<unknown, unknown>): string | undefined {
  if (Exit.isSuccess(exit)) return undefined
  const cause = exit.cause
  if (cause._tag === "Fail") return (cause.error as { _tag?: string })._tag
  return undefined
}

describe("LockService acquire/release", () => {
  describe("acquire / release", () => {
    it("acquires and releases a lock", async () => {
      await Effect.runPromise(
        LockService.pipe(
          Effect.flatMap((svc) =>
            Effect.gen(function* () {
              yield* svc.acquire("test-lock")
              yield* svc.release("test-lock")
            })
          ),
          Effect.scoped,
          Effect.provide(TestLayer)
        )
      )
    })

    it("release is idempotent", async () => {
      await Effect.runPromise(
        LockService.pipe(
          Effect.flatMap((svc) =>
            Effect.gen(function* () {
              yield* svc.acquire("test-lock")
              yield* svc.release("test-lock")
              yield* svc.release("test-lock")
            })
          ),
          Effect.scoped,
          Effect.provide(TestLayer)
        )
      )
    })

    it("can re-acquire after release", async () => {
      await Effect.runPromise(
        LockService.pipe(
          Effect.flatMap((svc) =>
            Effect.gen(function* () {
              yield* svc.acquire("test-lock")
              yield* svc.release("test-lock")
              yield* svc.acquire("test-lock")
              yield* svc.release("test-lock")
            })
          ),
          Effect.scoped,
          Effect.provide(TestLayer)
        )
      )
    })
  })

  describe("stale lock detection", () => {
    it("reclaims lock held by dead PID", async () => {
      await Effect.runPromise(
        Effect.gen(function* () {
          const db = yield* StoreService
          // Insert a lock with a PID that definitely doesn't exist
          yield* Effect.tryPromise(() =>
            db.insertInto("locks")
              .values({ name: "stale-lock", pid: 2147483647 })
              .execute()
          )

          const svc = yield* LockService
          // Should succeed by detecting the stale lock
          yield* svc.acquire("stale-lock")
          yield* svc.release("stale-lock")
        }).pipe(
          Effect.scoped,
          Effect.provide(TestLayer)
        )
      )
    })
  })

  describe("timeout", () => {
    it("times out when lock is held by live process", async () => {
      const exit = await Effect.runPromiseExit(
        Effect.gen(function* () {
          const db = yield* StoreService
          // Insert a lock held by our own PID (definitely alive)
          yield* Effect.tryPromise(() =>
            db.insertInto("locks")
              .values({ name: "busy-lock", pid: process.pid })
              .execute()
          )

          const svc = yield* LockService
          yield* svc.acquire("busy-lock", { timeout: 50, pollInterval: 10 })
        }).pipe(
          Effect.scoped,
          Effect.provide(TestLayer)
        )
      )

      expect(extractFailureTag(exit)).toBe("LockAcquireError")
    })
  })
})