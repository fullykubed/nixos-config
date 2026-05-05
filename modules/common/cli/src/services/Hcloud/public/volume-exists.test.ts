import { describe, it, expect } from "bun:test"
import { Context, Effect } from "effect"
import { HttpClient } from "@effect/platform"
import { volumeExists } from "./volume-exists"
import { mockHttp, volume1, defaultHcloudConfig } from "../test-helpers"
import { VolumeId } from "../types"
import { HcloudConfig } from "../config"

const provide = (http: HttpClient.HttpClient) =>
  Effect.provide(Context.empty().pipe(
    Context.add(HttpClient.HttpClient, http),
    Context.add(HcloudConfig, defaultHcloudConfig),
  ))

describe("volumeExists", () => {
  it("returns true when volume exists", async () => {
    const http = mockHttp(
      Response.json({ volume: volume1 }),
    )

    const result = await Effect.runPromise(
      volumeExists(VolumeId(200)).pipe(provide(http))
    )

    expect(result).toBe(true)
  })

  it("returns false when volume not found", async () => {
    const http = mockHttp(
      new Response(JSON.stringify({ error: { message: "Volume not found" } }), { status: 404 }),
    )

    const result = await Effect.runPromise(
      volumeExists(VolumeId(999)).pipe(provide(http))
    )

    expect(result).toBe(false)
  })
})
