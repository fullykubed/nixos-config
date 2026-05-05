import { describe, it, expect } from "bun:test"
import { Context, Effect, Option } from "effect"
import { HcloudService, HcloudServerNotFound } from "../../Hcloud"
import { TailscaleService, TailscaleDNSResolutionError } from "../../Tailscale"
import { SshService, SshConnectionError } from "../../Ssh"
import { ShellService } from "../../Shell"
import { getStats } from "./get-stats"
import { youngServer } from "../helpers.test"

/** 20-field pipe-delimited stats output matching the expected format. */
const validStatsOutput =
  "5|42|1000000|2000000|100|200|50000000|30000000|60|3|Running|2|10|1|500|100|204800|1|1|7\n"

const provide = (hcloudMock: any, tailscaleMock: any, sshMock: any, shellMock: any = {}) => {
  const ctx = Context.empty().pipe(
    Context.add(HcloudService, hcloudMock),
    Context.add(TailscaleService, tailscaleMock),
    Context.add(SshService, sshMock),
    Context.add(ShellService, shellMock),
  )
  return getStats("builder-1").pipe(Effect.provide(ctx))
}

describe("getStats", () => {
  it("returns null when server is not found in hcloud", async () => {
    const result = await Effect.runPromise(provide(
      { getServer: (n: string) => Effect.fail(new HcloudServerNotFound({ name: n })) },
      {},
      {},
      {}
    ))
    expect(Option.isNone(result)).toBe(true)
  })

  it("returns null when tailscale IP cannot be resolved", async () => {
    const result = await Effect.runPromise(provide(
      { getServer: () => Effect.succeed(youngServer) },
      { resolveIP: (h: string) => Effect.fail(new TailscaleDNSResolutionError({ hostname: h, error: "not found" })) },
      {},
      {}
    ))
    expect(Option.isNone(result)).toBe(true)
  })

  it("returns null when SSH command fails", async () => {
    const result = await Effect.runPromise(provide(
      { getServer: () => Effect.succeed(youngServer) },
      { resolveIP: () => Effect.succeed("100.64.0.1") },
      { exec: () => Effect.fail(new SshConnectionError({ host: "100.64.0.1", exitCode: 255, stderr: "connection refused" })) },
      {}
    ))
    expect(Option.isNone(result)).toBe(true)
  })

  it("returns parsed stats with uptime set from server creation time", async () => {
    const twoHoursAgo = new Date(Date.now() - 2 * 60 * 60_000).toISOString()
    const result = await Effect.runPromise(provide(
      { getServer: () => Effect.succeed({ ...youngServer, created: twoHoursAgo }) },
      { resolveIP: () => Effect.succeed("100.64.0.1") },
      { exec: () => Effect.succeed({ stdout: validStatsOutput, stderr: "", exitCode: 0 }) },
      {}
    ))
    expect(Option.isSome(result)).toBe(true)
    if (Option.isSome(result)) {
      expect(result.value.name).toBe("builder-1")
      expect(result.value.reachable).toBe(true)
      expect(result.value.builds).toBe(5)
      expect(result.value.uptimeHours).toBeGreaterThan(1.9)
    }
  })

  it("returns null when stats output has wrong number of fields", async () => {
    const result = await Effect.runPromise(provide(
      { getServer: () => Effect.succeed(youngServer) },
      { resolveIP: () => Effect.succeed("100.64.0.1") },
      { exec: () => Effect.succeed({ stdout: "bad|output|only|4|fields", stderr: "", exitCode: 0 }) },
      {}
    ))
    expect(Option.isNone(result)).toBe(true)
  })
})
