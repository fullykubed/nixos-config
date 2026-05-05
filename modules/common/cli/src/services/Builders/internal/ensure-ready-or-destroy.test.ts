import { describe, it, expect } from "bun:test"
import { Context, Effect } from "effect"
import { SilentLogger } from "../../../lib/test/logger"
import { HcloudService, HcloudServerNotFound } from "../../Hcloud"
import { TailscaleService } from "../../Tailscale"
import { ensureReadyOrDestroy } from "./ensure-ready-or-destroy"
import { baseHcloud, baseTailscale, youngServer } from "../helpers.test"

const provide = (hcloud: Partial<Parameters<typeof baseHcloud>[0]>, tailscale?: Partial<Parameters<typeof baseTailscale>[0]>) =>
  <A, E>(effect: Effect.Effect<A, E, any>) =>
    effect.pipe(
      Effect.provide(
        Context.empty().pipe(
          Context.add(HcloudService, baseHcloud(hcloud)),
          Context.add(TailscaleService, baseTailscale(tailscale)),
        )
      ),
      Effect.provide(SilentLogger),
    ) as Effect.Effect<A, E>

describe("ensureReadyOrDestroy", () => {
  it("returns true when builder is already ready", async () => {
    const result = await Effect.runPromise(
      ensureReadyOrDestroy("builder-1").pipe(
        provide(
          {
            serverExists: () => Effect.succeed(true),
            getServer: () => Effect.succeed(youngServer),
          },
          {
            isReachable: () => Effect.succeed(true),
            findPeer: () => Effect.succeed("100.64.0.5"),
          }
        )
      )
    )
    expect(result).toBe(true)
  })

  it("returns false when builder does not exist (gone)", async () => {
    const result = await Effect.runPromise(
      ensureReadyOrDestroy("builder-1").pipe(
        provide(
          {
            serverExists: () => Effect.succeed(false),
            getServer: () => Effect.fail(new HcloudServerNotFound({ name: "builder-1" })),
          },
          {
            isReachable: () => Effect.succeed(false),
            findPeer: () => Effect.fail({ _tag: "TailscaleDNSResolutionError", hostname: "builder-1", error: "not found" } as any),
          }
        )
      )
    )
    expect(result).toBe(false)
  })

  it("destroys stale builder (> 15 min old) that is not ready", async () => {
    let destroyed = false
    const oldServer = {
      ...youngServer,
      created: new Date(Date.now() - 20 * 60 * 1000).toISOString(), // 20 min ago
    }

    const result = await Effect.runPromise(
      ensureReadyOrDestroy("builder-1").pipe(
        provide(
          {
            serverExists: () => Effect.succeed(true),
            getServer: () => Effect.succeed(oldServer),
            deleteServer: () => { destroyed = true; return Effect.void },
          },
          {
            isReachable: () => Effect.succeed(false),
            findPeer: () => Effect.fail({ _tag: "TailscaleDNSResolutionError", hostname: "builder-1", error: "not found" } as any),
            deleteNode: () => Effect.void,
          }
        )
      )
    )
    expect(result).toBe(false)
    expect(destroyed).toBe(true)
  })
})
