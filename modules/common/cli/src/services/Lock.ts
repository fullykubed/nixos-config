import { Context, Data, Effect, Layer, Schedule } from "effect"
import type { Kysely } from "kysely"
import type { DB } from "./db"
import { StoreError, StoreService } from "./Store"

export class LockAcquireError extends Data.TaggedError("LockAcquireError")<{
  readonly name: string
  readonly message: string
  readonly cause?: StoreError
}> {}

export class LockCheckError extends Data.TaggedError("LockCheckError")<{
  readonly name: string
  readonly message: string
  readonly cause: StoreError
}> {}

export class LockReleaseError extends Data.TaggedError("LockReleaseError")<{
  readonly name: string
  readonly message: string
  readonly cause: StoreError
}> {}

export interface LockAcquireInfo {
  readonly waited: boolean
  readonly attempts: number
}

export interface LockServiceShape {
  isLocked(name: string): Effect.Effect<boolean, LockCheckError>
  acquire(name: string, opts?: { timeout?: number; pollInterval?: number }): Effect.Effect<LockAcquireInfo, LockAcquireError>
  release(name: string): Effect.Effect<void, LockReleaseError>
  withLock<A, E, R>(name: string, f: (info: LockAcquireInfo) => Effect.Effect<A, E, R>, opts?: { timeout?: number }): Effect.Effect<A, E | LockAcquireError, R>
}

export class LockService extends Context.Tag("LockService")<
  LockService,
  LockServiceShape
>() {}

const DEFAULT_TIMEOUT = 900_000
const DEFAULT_POLL_INTERVAL = 1_000

const isProcessAlive = (pid: number): boolean => {
  const result = Bun.spawnSync(["kill", "-0", String(pid)])
  return result.exitCode === 0
}

const toStoreError = (e: unknown): StoreError => new StoreError({
  operation: "lock",
  message: e instanceof Error ? e.message : String(e),
})

const makeLockService = (db: Kysely<DB>): LockServiceShape => {
  const myPid = process.pid

  const tryAcquire = async (name: string): Promise<boolean> => {
    const existing = await db.selectFrom("locks")
      .where("name", "=", name)
      .select(["pid"])
      .executeTakeFirst()

    if (!existing) {
      await db.insertInto("locks")
        .values({ name, pid: myPid })
        .execute()
      return true
    }

    // Stale detection: dead PID
    if (!isProcessAlive(existing.pid)) {
      await db.deleteFrom("locks").where("name", "=", name).execute()
      await db.insertInto("locks")
        .values({ name, pid: myPid })
        .execute()
      return true
    }

    return false
  }

  const isLocked = (name: string): Effect.Effect<boolean, LockCheckError> =>
    Effect.tryPromise({
      try: async () => {
        const existing = await db.selectFrom("locks")
          .where("name", "=", name)
          .select(["pid"])
          .executeTakeFirst()
        if (!existing) return false
        return isProcessAlive(existing.pid)
      },
      catch: (e) => new LockCheckError({ name, message: e instanceof Error ? e.message : String(e), cause: toStoreError(e) }),
    })

  const acquire = (name: string, opts?: { timeout?: number; pollInterval?: number }): Effect.Effect<LockAcquireInfo, LockAcquireError> => {
    const timeoutMs = opts?.timeout ?? DEFAULT_TIMEOUT
    const pollInterval = opts?.pollInterval ?? DEFAULT_POLL_INTERVAL
    const notAcquired = { _tag: "NotAcquired" as const }
    let attempts = 0

    return Effect.tryPromise({
      try: () => tryAcquire(name),
      catch: (e) => new LockAcquireError({ name, message: e instanceof Error ? e.message : String(e), cause: toStoreError(e) }),
    }).pipe(
      Effect.tap(() => { attempts++ }),
      Effect.flatMap((acquired) =>
        acquired ? Effect.void : Effect.fail(notAcquired)
      ),
      Effect.retry({
        while: (e) => e._tag === "NotAcquired",
        schedule: Schedule.spaced(pollInterval).pipe(Schedule.upTo(timeoutMs)),
      }),
      Effect.catchTag("NotAcquired", () =>
        Effect.fail(new LockAcquireError({ name, message: `Timed out after ${timeoutMs}ms` }))
      ),
      Effect.map(() => ({ waited: attempts > 1, attempts })),
    )
  }

  const release = (name: string): Effect.Effect<void, LockReleaseError> =>
    Effect.tryPromise({
      try: () => db.deleteFrom("locks").where("name", "=", name).execute(),
      catch: (e) => new LockReleaseError({ name, message: e instanceof Error ? e.message : String(e), cause: toStoreError(e) }),
    }).pipe(Effect.asVoid)

  const withLock = <A, E, R>(name: string, f: (info: LockAcquireInfo) => Effect.Effect<A, E, R>, opts?: { timeout?: number }): Effect.Effect<A, E | LockAcquireError, R> =>
    Effect.gen(function* () {
      const info = yield* acquire(name, opts)
      return yield* Effect.ensuring(f(info), Effect.ignore(release(name)))
    })

  return { isLocked, acquire, release, withLock }
}

export const LockLive: Layer.Layer<LockService, never, StoreService> = Layer.effect(
  LockService,
  Effect.gen(function* () {
    const db = yield* StoreService
    return makeLockService(db)
  })
)
