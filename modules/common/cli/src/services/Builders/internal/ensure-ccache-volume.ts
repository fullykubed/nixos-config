import { Effect } from "effect"
import type { HcloudService } from "../../Hcloud"
import { BUILDER_CONFIG } from "../config"

/**
 * Ensure a ccache volume exists for the given builder.
 * Creates a 50GB ext4 volume if one doesn't already exist.
 * Returns the volume ID and whether it was newly created.
 */
export const ensureCcacheVolume = (hcloud: HcloudService["Type"], name: string) =>
  Effect.gen(function* () {
    const volumeName = `ccache-${name}`
    const existingVolumes = yield* hcloud.listVolumes()
    const existingVolume = existingVolumes.find(vol => vol.name === volumeName)

    if (existingVolume) {
      return { volumeId: existingVolume.id, created: false }
    }

    yield* Effect.log(`Creating ccache volume ${volumeName} (50GB)...`)
    const newVolume = yield* hcloud.createVolume({
      name: volumeName,
      size: 50,
      location: BUILDER_CONFIG.location,
      labels: {
        "builder-ccache": "true",
        "builder-name": name
      },
      format: "ext4"
    })
    yield* Effect.log(`Created ccache volume ${volumeName}`)

    return { volumeId: newVolume.id, created: true }
  })
