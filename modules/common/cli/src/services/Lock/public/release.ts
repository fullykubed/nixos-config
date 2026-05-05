import { Effect } from "effect"
import { StoreService } from "../../Store"
import { LockReleaseError } from "../errors"
import { toStoreError } from "../internal/helpers"

export const release = (name: string) =>
  Effect.gen(function* () {
    const db = yield* StoreService
    yield* Effect.tryPromise({
      try: () => db.deleteFrom("locks").where("name", "=", name).execute(),
      catch: (e) => new LockReleaseError({ name, message: e instanceof Error ? e.message : String(e), cause: toStoreError(e) }),
    }).pipe(Effect.asVoid)
  })