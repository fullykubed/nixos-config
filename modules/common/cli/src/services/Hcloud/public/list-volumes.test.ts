import { describe, it, expect } from "bun:test"
import { Context, Effect, Exit } from "effect"
import { HttpClient } from "@effect/platform"
import { listVolumes } from "./list-volumes"
import { mockHttp, volume1, volume2, defaultHcloudConfig } from "../helpers.test"
import { HcloudConfig } from "../config"

const provide = (http: HttpClient.HttpClient) =>
  Effect.provide(Context.empty().pipe(
    Context.add(HttpClient.HttpClient, http),
    Context.add(HcloudConfig, defaultHcloudConfig),
  ))

describe("listVolumes", () => {
  it("returns empty list when no volumes exist", async () => {
    const http = mockHttp(
      Response.json({
        volumes: [],
        meta: { pagination: { next_page: null } },
      }),
    )

    const result = await Effect.runPromise(
      listVolumes().pipe(provide(http))
    )

    expect(result).toEqual([])
  })

  it("returns volumes from single page", async () => {
    const http = mockHttp(
      Response.json({
        volumes: [volume1, volume2],
        meta: { pagination: { next_page: null } },
      }),
    )

    const result = await Effect.runPromise(
      listVolumes().pipe(provide(http))
    )

    expect(result).toEqual([volume1, volume2])
  })

  it("fails with HcloudListVolumesError on HTTP error", async () => {
    const http = mockHttp(
      new Response(JSON.stringify({ error: { message: "Internal server error" } }), { status: 500 }),
    )

    const result = await Effect.runPromiseExit(
      listVolumes().pipe(provide(http))
    )

    expect(Exit.isFailure(result)).toBe(true)
    if (Exit.isFailure(result) && result.cause._tag === "Fail") {
      expect(result.cause.error._tag).toBe("HcloudListVolumesError")
    }
  })
})
