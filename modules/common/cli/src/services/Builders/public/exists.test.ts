import { describe, it, expect } from "bun:test"
import { Effect } from "effect"
import { HcloudService } from "../../Hcloud"
import { exists } from "./exists"

describe("exists", () => {
  it("returns true when server exists", async () => {
    expect(await Effect.runPromise(
      exists("builder-1").pipe(Effect.provideService(HcloudService, {
        serverExists: () => Effect.succeed(true),
      } as any))
    )).toBe(true)
  })

  it("returns false when server does not exist", async () => {
    expect(await Effect.runPromise(
      exists("builder-1").pipe(Effect.provideService(HcloudService, {
        serverExists: () => Effect.succeed(false),
      } as any))
    )).toBe(false)
  })

  it("returns false on any hcloud error", async () => {
    expect(await Effect.runPromise(
      exists("builder-1").pipe(Effect.provideService(HcloudService, {
        serverExists: () => Effect.fail(new Error("API unavailable")),
      } as any))
    )).toBe(false)
  })
})
