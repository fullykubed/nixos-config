import { describe, it, expect } from "bun:test"
import { Effect, Exit, Layer } from "effect"
import { BunContext } from "@effect/platform-bun"
import {
  TailscaleService,
  TailscaleLive,
} from "./Tailscale"
import { ShellService } from "./Shell"

const makeMockShell = (statusJson: object) =>
  Layer.succeed(ShellService, ShellService.of({
    exec: () => Effect.succeed({ stdout: "", stderr: "", exitCode: 0 }),
    execJson: () => Effect.succeed(statusJson) as Effect.Effect<never>,
    execLines: () => Effect.succeed([]),
  }))

function extractFailureTag(exit: Exit.Exit<unknown, unknown>): string | undefined {
  if (Exit.isSuccess(exit)) return undefined
  const cause = exit.cause
  if (cause._tag === "Fail") return (cause.error as { _tag?: string })._tag
  return undefined
}

describe("findPeer", () => {
  it("returns first TailscaleIP when peer is found", async () => {
    const statusJson = {
      BackendState: "Running",
      TUN: true,
      Online: true,
      TailscaleIPs: ["100.64.0.1"],
      Health: [],
      Peer: {
        "abc123": {
          HostName: "builder-1",
          TailscaleIPs: ["100.64.0.5", "fd7a::5"],
          Online: true,
        },
        "def456": {
          HostName: "builder-2",
          TailscaleIPs: ["100.64.0.6"],
          Online: true,
        },
      },
    }

    const layer = TailscaleLive.pipe(
      Layer.provide(makeMockShell(statusJson)),
      Layer.provide(BunContext.layer)
    )
    const result = await Effect.runPromise(
      TailscaleService.pipe(
        Effect.flatMap(svc => svc.findPeer("builder-1")),
        Effect.provide(layer)
      )
    )
    expect(result).toBe("100.64.0.5")
  })

  it("fails with TailscaleDNSResolutionError when peer is not found", async () => {
    const statusJson = {
      BackendState: "Running",
      TUN: true,
      Online: true,
      TailscaleIPs: ["100.64.0.1"],
      Health: [],
      Peer: {
        "abc123": {
          HostName: "builder-1",
          TailscaleIPs: ["100.64.0.5"],
          Online: true,
        },
      },
    }

    const layer = TailscaleLive.pipe(
      Layer.provide(makeMockShell(statusJson)),
      Layer.provide(BunContext.layer)
    )
    const exit = await Effect.runPromiseExit(
      TailscaleService.pipe(
        Effect.flatMap(svc => svc.findPeer("builder-99")),
        Effect.provide(layer)
      )
    )
    expect(Exit.isFailure(exit)).toBe(true)
    expect(extractFailureTag(exit)).toBe("TailscaleDNSResolutionError")
  })

  it("fails with TailscaleDNSResolutionError when there are no peers", async () => {
    const statusJson = {
      BackendState: "Running",
      TUN: true,
      Online: true,
      TailscaleIPs: ["100.64.0.1"],
      Health: [],
    }

    const layer = TailscaleLive.pipe(
      Layer.provide(makeMockShell(statusJson)),
      Layer.provide(BunContext.layer)
    )
    const exit = await Effect.runPromiseExit(
      TailscaleService.pipe(
        Effect.flatMap(svc => svc.findPeer("builder-1")),
        Effect.provide(layer)
      )
    )
    expect(Exit.isFailure(exit)).toBe(true)
    expect(extractFailureTag(exit)).toBe("TailscaleDNSResolutionError")
  })
})
