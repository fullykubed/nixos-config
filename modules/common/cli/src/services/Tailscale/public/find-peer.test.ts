import { describe, it, expect } from "bun:test"
import { Effect, Exit } from "effect"
import { ShellService } from "../../Shell"
import { findPeer } from "./find-peer"

function extractFailureTag(exit: Exit.Exit<unknown, unknown>): string | undefined {
  if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
    return (exit.cause.error as { _tag?: string })._tag
  }
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

    const result = await Effect.runPromise(
      findPeer("builder-1").pipe(
        Effect.provideService(ShellService, {
          exec: () => Effect.succeed({ stdout: "", stderr: "", exitCode: 0 }),
          execJson: () => Effect.succeed(statusJson),
          execLines: () => Effect.succeed([]),
        } as any)
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

    const exit = await Effect.runPromiseExit(
      findPeer("builder-99").pipe(
        Effect.provideService(ShellService, {
          exec: () => Effect.succeed({ stdout: "", stderr: "", exitCode: 0 }),
          execJson: () => Effect.succeed(statusJson),
          execLines: () => Effect.succeed([]),
        } as any)
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

    const exit = await Effect.runPromiseExit(
      findPeer("builder-1").pipe(
        Effect.provideService(ShellService, {
          exec: () => Effect.succeed({ stdout: "", stderr: "", exitCode: 0 }),
          execJson: () => Effect.succeed(statusJson),
          execLines: () => Effect.succeed([]),
        } as any)
      )
    )
    expect(Exit.isFailure(exit)).toBe(true)
    expect(extractFailureTag(exit)).toBe("TailscaleDNSResolutionError")
  })
})