import { Effect } from "effect"
import { BuildersService } from "../../../services/Builders"

/**
 * Check if server exists in Hetzner Cloud
 */
export const serverExists = (hostname: string) =>
  Effect.gen(function* () {
    const builders = yield* BuildersService
    return yield* builders.exists(hostname)
  })
