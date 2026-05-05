import { Effect, Schedule } from "effect"
import type { Kysely } from "kysely"
import type { DB } from "../../Store"
import { StoreService } from "../../Store"
import { LockAcquireError } from "../errors"
import { isProcessAlive, toStoreError } from "../internal/helpers"

const DEFAULT_TIMEOUT = 900_000
const DEFAULT_POLL_INTERVAL = 1_000

const tryAcquire = async (db: Kysely<DB>, name: string, myPid: number): Promise<boolean> => {
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

  if (!isProcessAlive(existing.pid)) {
    await db.deleteFrom("locks").where("name", "=", name).execute()
    await db.insertInto("locks")
      .values({ name, pid: myPid })
      .execute()
    return true
  }

  return false
}

export const acquire = (
  name: string,
  opts?: { timeout?: number; pollInterval?: number },
) => {
  const timeoutMs = opts?.timeout ?? DEFAULT_TIMEOUT
  const pollInterval = opts?.pollInterval ?? DEFAULT_POLL_INTERVAL
  const notAcquired = { _tag: "NotAcquired" as const }
  let attempts = 0

  return Effect.gen(function* () {
    const db = yield* StoreService
    const myPid = process.pid

    return yield* Effect.tryPromise({
      try: () => tryAcquire(db, name, myPid),
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
  })
}