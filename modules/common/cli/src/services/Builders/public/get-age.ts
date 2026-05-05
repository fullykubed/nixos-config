import { Effect } from "effect"
import { HcloudService } from "../../Hcloud"
import { BuilderNotFoundError } from "../errors"
import { calculateUptimeHours } from "../internal/calculate-uptime"

/**
 * Get the age of a builder in hours, based on its Hetzner creation time.
 */
export const getAge = (name: string) =>
  Effect.gen(function* () {
    const hcloud = yield* HcloudService
    return yield* hcloud.getServer(name).pipe(
      Effect.map((server) => calculateUptimeHours(server.created)),
      Effect.catchAll(() => Effect.fail(new BuilderNotFoundError({ name }))),
    )
  })
