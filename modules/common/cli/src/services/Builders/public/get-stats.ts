import { Effect, Either } from "effect"
import { HcloudService } from "../../Hcloud"
import { TailscaleService } from "../../Tailscale"
import { SshService } from "../../Ssh"
import { type BuilderStats } from "../types"
import { calculateUptimeHours } from "../internal/calculate-uptime"
import { REMOTE_STATS_CMD } from "../internal/stats-script"
import { parseStats } from "../internal/parse-stats"
import { BUILDER_CONFIG } from "../config"

/**
 * Fetch runtime stats from a builder via SSH.
 * Returns null if the builder is unreachable or the stats command fails.
 */
export const getStats = (name: string) =>
  Effect.gen(function* () {
    const hcloud = yield* HcloudService
    const tailscale = yield* TailscaleService
    const ssh = yield* SshService

    // Look up server to get creation time for uptime
    const serverResult = yield* hcloud.getServer(name).pipe(Effect.either)
    if (Either.isLeft(serverResult)) return null
    const uptimeHours = calculateUptimeHours(serverResult.right.created)

    // Try to resolve IP, return null if unreachable
    const ipResult = yield* tailscale.resolveIP(name).pipe(Effect.either)
    if (Either.isLeft(ipResult)) return null
    const ip = ipResult.right

    // Try to run stats command via SSH
    const sshResult = yield* ssh.exec(ip, REMOTE_STATS_CMD, {
      port: BUILDER_CONFIG.sshPort,
      connectTimeout: 10,
    }).pipe(Effect.either)
    if (Either.isLeft(sshResult)) return null

    // Parse output — parseStats throws on bad input
    const parsed = yield* Effect.try({
      try: () => parseStats(name, sshResult.right.stdout),
      catch: () => new Error("Failed to parse stats output"),
    }).pipe(Effect.catchAll(() => Effect.succeed(null as BuilderStats | null)))

    if (parsed) {
      parsed.uptimeHours = uptimeHours
    }

    return parsed
  })
