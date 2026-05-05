import { describe, it, expect } from "bun:test"
import { Context, Effect, Exit } from "effect"
import { HttpClient } from "@effect/platform"
import { getVolume } from "./get-volume"
import { mockHttp, volume1, defaultHcloudConfig } from "../test-helpers"
import { VolumeId } from "../types"
import { HcloudConfig } from "../config"

const provide = (http: HttpClient.HttpClient) =>
  Effect.provide(Context.empty().pipe(
    Context.add(HttpClient.HttpClient, http),
    Context.add(HcloudConfig, defaultHcloudConfig),
  ))

describe("getVolume", () => {
  it("gets volume by ID", async () => {
    const http = mockHttp(
      Response.json({ volume: volume1 }),
    )

    const result = await Effect.runPromise(
      getVolume(VolumeId(200)).pipe(provide(http))
    )

    expect(result).toEqual(volume1)
  })

  it("gets volume by name", async () => {
    const http = mockHttp(
      Response.json({ volumes: [volume1] }),
    )

    const result = await Effect.runPromise(
      getVolume("ccache-builder-1").pipe(provide(http))
    )

    expect(result).toEqual(volume1)
  })

  it("fails with HcloudVolumeNotFound when volume not found", async () => {
    const http = mockHttp(
      new Response(JSON.stringify({ error: { message: "Volume not found" } }), { status: 404 }),
    )

    const result = await Effect.runPromiseExit(
      getVolume(VolumeId(999)).pipe(provide(http))
    )

    expect(Exit.isFailure(result)).toBe(true)
    if (Exit.isFailure(result) && result.cause._tag === "Fail") {
      expect(result.cause.error._tag).toBe("HcloudVolumeNotFound")
    }
  })
})
