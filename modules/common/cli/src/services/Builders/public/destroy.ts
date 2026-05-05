import { Effect } from "effect"
import { HcloudService } from "../../Hcloud"
import { TailscaleService } from "../../Tailscale"
import { BuilderDestroyError } from "../errors"

/**
 * Destroy a builder: delete server, remove headscale node.
 * The operation is uninterruptible to avoid partial teardown.
 */
export const destroy = (name: string) =>
  Effect.uninterruptible(Effect.gen(function* () {
    const hcloud = yield* HcloudService
    const tailscale = yield* TailscaleService

    // Delete server (wait for it to be fully gone)
    yield* hcloud.deleteServer(name, { wait: true }).pipe(
      Effect.catchAll((err) =>
        Effect.fail(new BuilderDestroyError({
          name,
          message: "Failed to delete server",
          cause: err,
        }))
      )
    )

    // Delete headscale node (best-effort)
    yield* tailscale.deleteNode(name).pipe(
      Effect.catchAll(() => Effect.logWarning(`Failed to remove ${name} from headscale`))
    )
  }))
