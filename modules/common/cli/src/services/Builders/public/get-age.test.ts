import { describe, it, expect } from "bun:test"
import { Effect, Exit } from "effect"
import { HcloudService, HcloudServerNotFound } from "../../Hcloud"
import { getAge } from "./get-age"
import { youngServer } from "../helpers.test"

describe("getAge", () => {
  it("returns age in hours based on server creation time", async () => {
    const twoHoursAgo = new Date(Date.now() - 2 * 60 * 60_000).toISOString()
    const age = await Effect.runPromise(
      getAge("builder-1").pipe(Effect.provideService(HcloudService, {
        getServer: () => Effect.succeed({ ...youngServer, created: twoHoursAgo }),
      } as any))
    )
    expect(age).toBeGreaterThanOrEqual(1.9)
    expect(age).toBeLessThanOrEqual(2.1)
  })

  it("returns near-zero for a recently created server", async () => {
    const justNow = new Date(Date.now() - 10_000).toISOString()
    const age = await Effect.runPromise(
      getAge("builder-1").pipe(Effect.provideService(HcloudService, {
        getServer: () => Effect.succeed({ ...youngServer, created: justNow }),
      } as any))
    )
    expect(age).toBeLessThan(0.01)
  })

  it("fails with BuilderNotFoundError when server does not exist", async () => {
    const exit = await Effect.runPromiseExit(
      getAge("builder-1").pipe(Effect.provideService(HcloudService, {
        getServer: (n: string) => Effect.fail(new HcloudServerNotFound({ name: n })),
      } as any))
    )
    expect(Exit.isFailure(exit)).toBe(true)
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      expect(exit.cause.error._tag).toBe("BuilderNotFoundError")
      expect(exit.cause.error.name).toBe("builder-1")
    }
  })
})
