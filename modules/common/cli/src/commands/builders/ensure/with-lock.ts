import { Effect } from "effect"
import { LockService, type LockAcquireInfo } from "../../../services/Lock"

export const withLock = <A, E, R>(lockName: string, f: (info: LockAcquireInfo) => Effect.Effect<A, E, R>) =>
  Effect.gen(function* () {
    const svc = yield* LockService
    return yield* svc.withLock(lockName, f)
  })
