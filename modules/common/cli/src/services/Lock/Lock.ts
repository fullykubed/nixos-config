import { Context, Effect, Layer } from "effect"
import { StoreService } from "../Store"
import { mkContextInjector } from "../../lib/mkContextInjector"
import { type LockAcquireInfo } from "./errors"
import { isLocked } from "./public/is-locked"
import { acquire } from "./public/acquire"
import { release } from "./public/release"
import { withLock } from "./public/with-lock"

export {
  LockAcquireError,
  LockCheckError,
  LockReleaseError,
  type LockAcquireInfo,
} from "./errors"

const make = Effect.gen(function* () {
  const db = yield* StoreService
  const ctx = Context.empty().pipe(Context.add(StoreService, db))
  const inject = mkContextInjector(ctx, "Lock")
  const provide = Effect.provide(ctx)

  return {
    isLocked: inject(isLocked),
    acquire: inject(acquire),
    release: inject(release),
    withLock: <A, E, R>(name: string, f: (info: LockAcquireInfo) => Effect.Effect<A, E, R>, opts?: { timeout?: number }) =>
      provide(withLock(name, f, opts)),
  }
})

export type LockServiceShape = Effect.Effect.Success<typeof make>

export class LockService extends Context.Tag("LockService")<
  LockService,
  LockServiceShape
>() {}

export const LockLive = Layer.effect(LockService, make)
