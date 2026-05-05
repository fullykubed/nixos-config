import { describe, it, expect } from "bun:test"
import { Effect, Exit } from "effect"
import { TailscaleService, TailscaleDNSResolutionError } from "../../Tailscale"
import { resolveIP } from "./resolve-ip"

describe("resolveIP", () => {
  it("returns the IP when tailscale resolves successfully", async () => {
    expect(await Effect.runPromise(
      resolveIP("builder-1").pipe(Effect.provideService(TailscaleService, {
        resolveIP: () => Effect.succeed("100.64.0.1"),
      } as any))
    )).toBe("100.64.0.1")
  })

  it("fails with BuilderUnreachableError when tailscale resolution fails", async () => {
    const exit = await Effect.runPromiseExit(
      resolveIP("builder-1").pipe(Effect.provideService(TailscaleService, {
        resolveIP: (h: string) => Effect.fail(new TailscaleDNSResolutionError({ hostname: h, error: "not found" })),
      } as any))
    )
    expect(Exit.isFailure(exit)).toBe(true)
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      expect(exit.cause.error._tag).toBe("BuilderUnreachableError")
      expect(exit.cause.error.name).toBe("builder-1")
      expect(exit.cause.error.reason).toBe("Tailscale IP resolution failed")
    }
  })
})
