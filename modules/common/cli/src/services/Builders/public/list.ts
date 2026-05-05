import { Effect } from "effect"
import { HcloudService } from "../../Hcloud"
import { BUILDER_CONFIG } from "../config"

/**
 * List all builder servers, sorted by name.
 */
export const list = () =>
  Effect.gen(function* () {
    const hcloud = yield* HcloudService
    const servers = yield* hcloud.listServers()
    return servers
      .filter(s => BUILDER_CONFIG.builderPattern.test(s.name))
      .sort((a, b) => a.name.localeCompare(b.name))
  })
