import { describe, it, expect } from "bun:test"
import { Effect } from "effect"
import { HcloudService, HcloudListServersError } from "../../Hcloud"
import { list } from "./list"
import { youngServer } from "../helpers.test"
import type { Server } from "../../Hcloud"

const server = (name: string): Server => ({ ...youngServer, name })

describe("list", () => {
  it("returns only builder servers filtered by pattern", async () => {
    const result = await Effect.runPromise(
      list().pipe(Effect.provideService(HcloudService, {
        listServers: () => Effect.succeed([
          server("builder-1"),
          server("builder-2"),
          server("my-other-server"),
        ]),
      } as any))
    )
    expect(result.map(s => s.name)).toEqual(["builder-1", "builder-2"])
  })

  it("sorts results by name", async () => {
    const result = await Effect.runPromise(
      list().pipe(Effect.provideService(HcloudService, {
        listServers: () => Effect.succeed([
          server("builder-3"),
          server("big-builder-1"),
          server("builder-1"),
        ]),
      } as any))
    )
    expect(result.map(s => s.name)).toEqual(["big-builder-1", "builder-1", "builder-3"])
  })

  it("returns empty list when no builders exist", async () => {
    const result = await Effect.runPromise(
      list().pipe(Effect.provideService(HcloudService, {
        listServers: () => Effect.succeed([server("other-server")]),
      } as any))
    )
    expect(result).toEqual([])
  })

  it("propagates listServers errors", async () => {
    const exit = await Effect.runPromiseExit(
      list().pipe(Effect.provideService(HcloudService, {
        listServers: () => Effect.fail(new HcloudListServersError({ message: "API error" })),
      } as any))
    )
    expect(exit._tag).toBe("Failure")
  })
})
