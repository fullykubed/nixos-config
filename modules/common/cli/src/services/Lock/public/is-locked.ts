import { Effect } from "effect"
import { StoreService } from "../../Store"
import { LockCheckError } from "../errors"
import { isProcessAlive, toStoreError } from "../internal/helpers"

export const isLocked = (name: string) =>
  Effect.gen(function* () {
    const db = yield* StoreService
    return yield* Effect.tryPromise({
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
  })