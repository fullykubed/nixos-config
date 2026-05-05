import { describe, it, expect } from "bun:test"
import { Effect, Exit } from "effect"
import { HcloudService, HcloudServerNotFound } from "../../Hcloud"
import { get } from "./get"
import { youngServer } from "../helpers.test"

describe("get", () => {
  it("returns the server when found", async () => {
    const result = await Effect.runPromise(
      get("builder-1").pipe(Effect.provideService(HcloudService, {
        getServer: () => Effect.succeed(youngServer),
      } as any))
    )
    expect(result.name).toBe("builder-1")
  })

  it("fails with BuilderNotFoundError when hcloud returns not-found", async () => {
    const exit = await Effect.runPromiseExit(
      get("builder-1").pipe(Effect.provideService(HcloudService, {
        getServer: (n: string) => Effect.fail(new HcloudServerNotFound({ name: n })),
      } as any))
    )
    expect(Exit.isFailure(exit)).toBe(true)
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      expect(exit.cause.error._tag).toBe("BuilderNotFoundError")
      expect(exit.cause.error.name).toBe("builder-1")
    }
  })

  it("wraps any hcloud error as BuilderNotFoundError", async () => {
    const exit = await Effect.runPromiseExit(
      get("builder-1").pipe(Effect.provideService(HcloudService, {
        getServer: () => Effect.fail(new Error("network timeout")),
      } as any))
    )
    expect(Exit.isFailure(exit)).toBe(true)
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      expect(exit.cause.error._tag).toBe("BuilderNotFoundError")
    }
  })
})
