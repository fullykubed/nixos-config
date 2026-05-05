import { describe, it, expect } from "bun:test"
import { Effect, Exit } from "effect"
import { ShellService } from "../../Shell"
import { status } from "./status"

function extractFailureTag(exit: Exit.Exit<unknown, unknown>): string | undefined {
  if (Exit.isSuccess(exit)) return undefined
  const cause = exit.cause
  if (cause._tag === "Fail") return (cause.error as { _tag?: string })._tag
  return undefined
}

const mockShell = (json: unknown) => ShellService.of({
  exec: () => Effect.succeed({ stdout: "", stderr: "", exitCode: 0 }),
  execJson: () => Effect.succeed(json),
  execLines: () => Effect.succeed([]),
} as any)

describe("status", () => {
  it("returns status when BackendState is Running", async () => {
    const statusJson = {
      BackendState: "Running",
      TUN: true,
      Online: true,
      TailscaleIPs: ["100.64.0.1"],
      Health: [],
    }
    const result = await Effect.runPromise(
      status().pipe(Effect.provideService(ShellService, mockShell(statusJson)))
    )
    expect(result.BackendState).toBe("Running")
    expect(result.TailscaleIPs).toEqual(["100.64.0.1"])
  })

  it("fails with TailscaleNotConnectedError when BackendState is Stopped", async () => {
    const statusJson = {
      BackendState: "Stopped",
      TUN: false,
      Online: false,
      TailscaleIPs: [],
      Health: [],
    }
    const exit = await Effect.runPromiseExit(
      status().pipe(Effect.provideService(ShellService, mockShell(statusJson)))
    )
    expect(Exit.isFailure(exit)).toBe(true)
    expect(extractFailureTag(exit)).toBe("TailscaleNotConnectedError")
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      const error = exit.cause.error as { backendState: string; message: string }
      expect(error.backendState).toBe("Stopped")
      expect(error.message).toContain("Stopped")
    }
  })

  it("fails with TailscaleNotConnectedError when BackendState is NeedsLogin", async () => {
    const statusJson = {
      BackendState: "NeedsLogin",
      TUN: false,
      Online: false,
      TailscaleIPs: [],
      Health: [],
    }
    const exit = await Effect.runPromiseExit(
      status().pipe(Effect.provideService(ShellService, mockShell(statusJson)))
    )
    expect(Exit.isFailure(exit)).toBe(true)
    expect(extractFailureTag(exit)).toBe("TailscaleNotConnectedError")
  })

  it("propagates ShellError when execJson fails", async () => {
    const shell = ShellService.of({
      exec: () => Effect.succeed({ stdout: "", stderr: "", exitCode: 0 }),
      execJson: () => Effect.fail({ _tag: "ShellError", command: "tailscale status --json", exitCode: 1, stdout: "", stderr: "not installed" }),
      execLines: () => Effect.succeed([]),
    } as any)

    const exit = await Effect.runPromiseExit(
      status().pipe(Effect.provideService(ShellService, shell))
    )
    expect(Exit.isFailure(exit)).toBe(true)
  })

  it("returns full status with Peer map", async () => {
    const statusJson = {
      BackendState: "Running",
      TUN: true,
      Online: true,
      TailscaleIPs: ["100.64.0.1"],
      Health: [],
      Peer: {
        "abc": { HostName: "builder-1", TailscaleIPs: ["100.64.0.5"], Online: true },
      },
    }
    const result = await Effect.runPromise(
      status().pipe(Effect.provideService(ShellService, mockShell(statusJson)))
    )
    expect(result.Peer?.abc?.HostName).toBe("builder-1")
  })
})
