import { describe, it, expect } from "bun:test"
import { Effect, Exit } from "effect"
import { ShellService, ShellError } from "../../Shell"
import { resolveIP } from "./resolve-ip"

function extractFailureTag(exit: Exit.Exit<unknown, unknown>): string | undefined {
  if (Exit.isSuccess(exit)) return undefined
  const cause = exit.cause
  if (cause._tag === "Fail") return (cause.error as { _tag?: string })._tag
  return undefined
}

const mockShell = (stdout: string) => ShellService.of({
  exec: () => Effect.succeed({ stdout, stderr: "", exitCode: 0 }),
  execJson: () => Effect.succeed({}),
  execLines: () => Effect.succeed([]),
} as any)

describe("resolveIP", () => {
  it("returns trimmed IPv4 address on success", async () => {
    const result = await Effect.runPromise(
      resolveIP("builder-1").pipe(
        Effect.provideService(ShellService, mockShell("100.64.0.5\n"))
      )
    )
    expect(result).toBe("100.64.0.5")
  })

  it("handles address with extra whitespace", async () => {
    const result = await Effect.runPromise(
      resolveIP("builder-1").pipe(
        Effect.provideService(ShellService, mockShell("  100.64.0.10  \n"))
      )
    )
    expect(result).toBe("100.64.0.10")
  })

  it("fails with TailscaleDNSResolutionError for empty output", async () => {
    const exit = await Effect.runPromiseExit(
      resolveIP("builder-1").pipe(
        Effect.provideService(ShellService, mockShell(""))
      )
    )
    expect(Exit.isFailure(exit)).toBe(true)
    expect(extractFailureTag(exit)).toBe("TailscaleDNSResolutionError")
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      const error = exit.cause.error as { hostname: string; error: string }
      expect(error.hostname).toBe("builder-1")
      expect(error.error).toContain("Invalid IP address")
    }
  })

  it("fails with TailscaleDNSResolutionError for non-IP output", async () => {
    const exit = await Effect.runPromiseExit(
      resolveIP("builder-1").pipe(
        Effect.provideService(ShellService, mockShell("not-an-ip\n"))
      )
    )
    expect(Exit.isFailure(exit)).toBe(true)
    expect(extractFailureTag(exit)).toBe("TailscaleDNSResolutionError")
  })

  it("fails with TailscaleDNSResolutionError for IPv6 address", async () => {
    const exit = await Effect.runPromiseExit(
      resolveIP("builder-1").pipe(
        Effect.provideService(ShellService, mockShell("fd7a::1\n"))
      )
    )
    expect(Exit.isFailure(exit)).toBe(true)
    expect(extractFailureTag(exit)).toBe("TailscaleDNSResolutionError")
  })

  it("fails with TailscaleDNSResolutionError when shell command fails", async () => {
    const failingShell = ShellService.of({
      exec: () => Effect.fail(new ShellError({
        command: "tailscale ip -4 builder-1",
        exitCode: 1,
        stdout: "",
        stderr: "no matching peer"
      })),
      execJson: () => Effect.succeed({}),
      execLines: () => Effect.succeed([]),
    } as any)

    const exit = await Effect.runPromiseExit(
      resolveIP("builder-1").pipe(
        Effect.provideService(ShellService, failingShell)
      )
    )
    expect(Exit.isFailure(exit)).toBe(true)
    expect(extractFailureTag(exit)).toBe("TailscaleDNSResolutionError")
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      const error = exit.cause.error as { hostname: string }
      expect(error.hostname).toBe("builder-1")
    }
  })
})
