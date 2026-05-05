import { Effect } from "effect"
import { ShellService } from "../../Shell"
import { TailscaleDNSResolutionError } from "../errors"

export const resolveIP = (hostname: string) =>
  Effect.gen(function* () {
    const shell = yield* ShellService
    const result = yield* shell.exec("tailscale", ["ip", "-4", hostname]).pipe(
      Effect.catchAll((error) => Effect.fail(new TailscaleDNSResolutionError({
        hostname,
        error: error.stderr || String(error)
      })))
    )
    const ip = result.stdout.trim()
    if (!ip || !/^\d+\.\d+\.\d+\.\d+$/.test(ip)) {
      return yield* Effect.fail(new TailscaleDNSResolutionError({
        hostname,
        error: `Invalid IP address returned: ${ip}`
      }))
    }
    return ip
  })