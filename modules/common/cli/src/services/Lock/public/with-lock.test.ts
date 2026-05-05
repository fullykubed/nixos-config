import { describe, it, expect } from "bun:test"
import { Effect, Exit, Layer } from "effect"
import { BunContext } from "@effect/platform-bun"
import { LockService, LockLive } from "../Lock"
import { makeStoreLive } from "../../Store"

const TestStore = makeStoreLive(":memory:").pipe(Layer.provide(BunContext.layer))
const TestLock = LockLive.pipe(Layer.provide(TestStore))
const TestLayer = Layer.merge(TestStore, TestLock)

describe("LockService withLock", () => {
  describe("withLock", () => {
    it("releases lock on success", async () => {
      const result = await Effect.runPromise(
        LockService.pipe(
          Effect.flatMap((svc) =>
            Effect.gen(function* () {
              const value = yield* svc.withLock("wl-test", () => Effect.succeed(42))
              // Lock should be released — acquiring again should succeed
              yield* svc.acquire("wl-test")
              yield* svc.release("wl-test")
              return value
            })
          ),
          Effect.scoped,
          Effect.provide(TestLayer)
        )
      )
      expect(result).toBe(42)
    })

    it("passes acquire info to the callback", async () => {
      const info = await Effect.runPromise(
        LockService.pipe(
          Effect.flatMap((svc) =>
            svc.withLock("wl-info", (lockInfo) => Effect.succeed(lockInfo))
          ),
          Effect.scoped,
          Effect.provide(TestLayer)
        )
      )
      expect(info.waited).toBe(false)
      expect(info.attempts).toBe(1)
    })

    it("releases lock on failure", async () => {
      const exit = await Effect.runPromiseExit(
        LockService.pipe(
          Effect.flatMap((svc) =>
            svc.withLock("wl-fail", () => Effect.fail("boom"))
          ),
          Effect.scoped,
          Effect.provide(TestLayer)
        )
      )

      expect(Exit.isFailure(exit)).toBe(true)

      // Lock should be released — acquiring again should succeed
      await Effect.runPromise(
        LockService.pipe(
          Effect.flatMap((svc) =>
            Effect.gen(function* () {
              yield* svc.acquire("wl-fail")
              yield* svc.release("wl-fail")
            })
          ),
          Effect.scoped,
          Effect.provide(TestLayer)
        )
      )
    })
  })
})