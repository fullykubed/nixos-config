import { Effect } from "effect"
import { HcloudService } from "../../Hcloud"

/**
 * Check whether a builder exists in Hetzner Cloud.
 * Returns false on any error.
 */
export const exists = (name: string) =>
  Effect.gen(function* () {
    const hcloud = yield* HcloudService
    return yield* hcloud.serverExists(name).pipe(
      Effect.catchAll(() => Effect.succeed(false))
    )
  })
