import { Effect } from "effect"
import { TailscaleService } from "../../Tailscale"
import { BuilderUnreachableError } from "../errors"

/**
 * Resolve a builder's Tailscale IPv4 address.
 */
export const resolveIP = (name: string) =>
  Effect.gen(function* () {
    const tailscale = yield* TailscaleService
    return yield* tailscale.resolveIP(name).pipe(
      Effect.catchAll((err) =>
        Effect.fail(new BuilderUnreachableError({
          name,
          reason: "Tailscale IP resolution failed",
          cause: err,
        }))
      )
    )
  })
