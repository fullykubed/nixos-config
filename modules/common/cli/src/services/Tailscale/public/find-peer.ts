import { Effect } from "effect"
import { ShellService } from "../../Shell"
import { TailscaleDNSResolutionError } from "../errors"
import type { TailscaleStatus } from "../types"

export const findPeer = (hostname: string) =>
  Effect.gen(function* () {
    const shell = yield* ShellService
    const statusResult = yield* shell.execJson<TailscaleStatus>("tailscale", ["status", "--json"])
    const peer = Object.values(statusResult.Peer ?? {}).find(p => p.HostName === hostname)
    const ip = peer?.TailscaleIPs[0]
    if (!ip) {
      return yield* Effect.fail(new TailscaleDNSResolutionError({
        hostname,
        error: "Peer not found in tailscale status"
      }))
    }
    return ip
  })