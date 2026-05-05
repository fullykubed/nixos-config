import { Effect } from "effect"
import { HcloudService } from "../../Hcloud"
import { BuilderNotFoundError } from "../errors"

/**
 * Get a single builder by its (already-normalized) name.
 */
export const get = (name: string) =>
  Effect.gen(function* () {
    const hcloud = yield* HcloudService
    return yield* hcloud.getServer(name).pipe(
      Effect.catchAll(() => Effect.fail(new BuilderNotFoundError({ name })))
    )
  })
