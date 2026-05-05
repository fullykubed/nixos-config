import { Effect } from "effect"
import { type LockAcquireInfo } from "../errors"
import { acquire } from "./acquire"
import { release } from "./release"

export const withLock = <A, E, R>(
  name: string,
  f: (info: LockAcquireInfo) => Effect.Effect<A, E, R>,
  opts?: { timeout?: number },
) =>
  Effect.gen(function* () {
    const info = yield* acquire(name, opts)
    return yield* Effect.ensuring(f(info), Effect.ignore(release(name)))
  })