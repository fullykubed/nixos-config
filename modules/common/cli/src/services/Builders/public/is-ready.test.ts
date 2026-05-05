import { describe, it, expect } from "bun:test"
import { Context, Effect, Exit } from "effect"
import { HcloudService } from "../../Hcloud"
import { TailscaleService, TailscaleDNSResolutionError } from "../../Tailscale"
import { isReady } from "./is-ready"

const provide = (hcloudMock: any, tailscaleMock: any) => {
  const ctx = Context.empty().pipe(
    Context.add(HcloudService, hcloudMock),
    Context.add(TailscaleService, tailscaleMock),
  )
  return <A, E>(effect: Effect.Effect<A, E, HcloudService | TailscaleService>) =>
    effect.pipe(Effect.provide(ctx))
}

describe("isReady", () => {
  it("returns true when server exists and is reachable", async () => {
    const run = provide(
      { serverExists: () => Effect.succeed(true) },
      { resolveIP: () => Effect.succeed("100.64.0.1"), isReachable: () => Effect.succeed(true) },
    )
    expect(await Effect.runPromise(run(isReady("builder-1")))).toBe(true)
  })

  it("returns false when server exists but tailscale resolution fails", async () => {
    const run = provide(
      { serverExists: () => Effect.succeed(true) },
      { resolveIP: (h: string) => Effect.fail(new TailscaleDNSResolutionError({ hostname: h, error: "not found" })) },
    )
    expect(await Effect.runPromise(run(isReady("builder-1")))).toBe(false)
  })

  it("returns false when IP resolves but SSH port is closed", async () => {
    const run = provide(
      { serverExists: () => Effect.succeed(true) },
      { resolveIP: () => Effect.succeed("100.64.0.1"), isReachable: () => Effect.succeed(false) },
    )
    expect(await Effect.runPromise(run(isReady("builder-1")))).toBe(false)
  })

  it("fails with BuilderNotFoundError when server does not exist", async () => {
    const run = provide(
      { serverExists: () => Effect.succeed(false) },
      {},
    )
    const exit = await Effect.runPromiseExit(run(isReady("builder-1")))
    expect(Exit.isFailure(exit)).toBe(true)
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      expect(exit.cause.error._tag).toBe("BuilderNotFoundError")
      expect(exit.cause.error.name).toBe("builder-1")
    }
  })

  it("treats hcloud errors as server not found", async () => {
    const run = provide(
      { serverExists: () => Effect.fail(new Error("API error")) },
      {},
    )
    const exit = await Effect.runPromiseExit(run(isReady("builder-1")))
    expect(Exit.isFailure(exit)).toBe(true)
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      expect(exit.cause.error._tag).toBe("BuilderNotFoundError")
    }
  })
})
