import { describe, it, expect } from "bun:test"
import { Context, Effect, Exit } from "effect"
import { SilentLogger } from "../../../lib/test/logger"
import { HcloudService } from "../../Hcloud"
import { TailscaleService } from "../../Tailscale"
import { destroy } from "./destroy"

const provide = (hcloudMock: any, tailscaleMock: any) => {
  const ctx = Context.empty().pipe(
    Context.add(HcloudService, hcloudMock),
    Context.add(TailscaleService, tailscaleMock),
  )
  return <A, E>(effect: Effect.Effect<A, E, HcloudService | TailscaleService>) =>
    effect.pipe(Effect.provide(ctx), Effect.provide(SilentLogger))
}

describe("destroy", () => {
  it("succeeds when server deletion and headscale removal both succeed", async () => {
    let deleteCalled = false
    let deleteNodeCalled = false
    const run = provide(
      { deleteServer: () => { deleteCalled = true; return Effect.void } },
      { deleteNode: () => { deleteNodeCalled = true; return Effect.void } },
    )
    await Effect.runPromise(run(destroy("builder-1")))
    expect(deleteCalled).toBe(true)
    expect(deleteNodeCalled).toBe(true)
  })

  it("fails with BuilderDestroyError when server deletion fails", async () => {
    const run = provide(
      { deleteServer: () => Effect.fail(new Error("deletion failed")) },
      { deleteNode: () => Effect.void },
    )
    const exit = await Effect.runPromiseExit(run(destroy("builder-1")))
    expect(Exit.isFailure(exit)).toBe(true)
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      expect(exit.cause.error._tag).toBe("BuilderDestroyError")
      expect(exit.cause.error.name).toBe("builder-1")
      expect(exit.cause.error.message).toBe("Failed to delete server")
    }
  })

  it("still succeeds when headscale node removal fails (best-effort)", async () => {
    let deleteCalled = false
    const run = provide(
      { deleteServer: () => { deleteCalled = true; return Effect.void } },
      { deleteNode: () => Effect.fail(new Error("headscale unreachable")) },
    )
    await Effect.runPromise(run(destroy("builder-1")))
    expect(deleteCalled).toBe(true)
  })
})
