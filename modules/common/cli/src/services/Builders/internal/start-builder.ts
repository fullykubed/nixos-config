import { Effect } from "effect"
import type { HcloudService } from "../../Hcloud"
import type { Server } from "../../Hcloud"
import { BUILDER_CONFIG } from "../config"

/**
 * Create the Hetzner server and wait for it to reach "running" status.
 * Returns the created server and the final server type (which may differ
 * from the requested one if a fallback was used).
 */
export const startBuilder = (hcloud: HcloudService["Type"], opts: {
  name: string
  builderType: "regular" | "big"
  serverType: string
  imageId: number
  volumeId: number
  volumeCreated: boolean
  crocCode: string
  crocRelayPass: string
}) =>
  Effect.gen(function* () {
    // Build cloud-init user data
    const userData = `#cloud-config
ssh_pwauth: false
chpasswd:
  expire: false
write_files:
  - path: /run/croc-relay-password
    permissions: '0444'
    content: |
      ${opts.crocRelayPass}
  - path: /run/croc-code
    permissions: '0400'
    content: |
      ${opts.crocCode}
`

    // Create server and wait for it to be running
    let finalServerType = opts.serverType
    yield* Effect.log(`Waiting for ${opts.name} to be running...`)

    const createOpts = {
      name: opts.name,
      type: opts.serverType,
      location: BUILDER_CONFIG.location,
      image: opts.imageId,
      userData,
      volumes: [opts.volumeId],
      labels: {
        builder: "true",
        type: "builder",
        size: opts.builderType
      },
      waitForRunning: true,
    }

    const server: Server = yield* hcloud.createServer(createOpts).pipe(
      Effect.catchTag("HcloudCreateServerError", (err) => {
        // Fall back to smaller server type for regular builders
        if (opts.builderType === "regular" && opts.serverType !== BUILDER_CONFIG.regularFallbackServerType) {
          finalServerType = BUILDER_CONFIG.regularFallbackServerType
          return Effect.logWarning(`${opts.serverType} unavailable, falling back to ${BUILDER_CONFIG.regularFallbackServerType}...`).pipe(
            Effect.andThen(hcloud.createServer({ ...createOpts, type: finalServerType }))
          )
        }
        return Effect.fail(err)
      })
    )

    yield* Effect.log(`${opts.name} is running (${finalServerType}, ${server.public_net.ipv4.ip})`)
    if (opts.volumeCreated) {
      yield* Effect.log(`Attached ccache volume ccache-${opts.name}`)
    }

    return { server, finalServerType }
  })
