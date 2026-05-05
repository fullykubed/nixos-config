import { Effect } from "effect"
import { HcloudService } from "../../Hcloud"
import { TailscaleService } from "../../Tailscale"
import { BuilderNotFoundError } from "../errors"

/**
 * Check whether a builder is reachable over Tailscale (SSH port 22).
 * Fails with BuilderNotFoundError if the server doesn't exist in Hetzner Cloud.
 */
export const isReady = (name: string) =>
  Effect.gen(function* () {
    const hcloud = yield* HcloudService
    const tailscale = yield* TailscaleService
    const serverExists = yield* hcloud.serverExists(name).pipe(
      Effect.catchAll(() => Effect.succeed(false))
    )
    if (!serverExists) {
      return yield* Effect.fail(new BuilderNotFoundError({ name }))
    }
    return yield* tailscale.resolveIP(name).pipe(
      Effect.flatMap((ip) => tailscale.isReachable(ip, 22)),
      Effect.catchAll(() => Effect.succeed(false)),
    )
  })
