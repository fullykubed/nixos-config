import { describe, it, expect } from "bun:test"
import { Context, Effect, Exit } from "effect"
import { HttpClient } from "@effect/platform"
import { detachVolume } from "./detach-volume"
import { mockHttp, volume2, defaultHcloudConfig } from "../helpers.test"
import { VolumeId } from "../types"
import { HcloudConfig } from "../config"

const provide = (http: HttpClient.HttpClient) =>
  Effect.provide(Context.empty().pipe(
    Context.add(HttpClient.HttpClient, http),
    Context.add(HcloudConfig, defaultHcloudConfig),
  ))

describe("detachVolume", () => {
  it("detaches volume by ID", async () => {
    const http = mockHttp(
      // getVolume response
      Response.json({ volume: volume2 }),
      // detach response
      new Response(JSON.stringify({ action: { id: 123, status: "running" } }), { status: 201 }),
    )

    await Effect.runPromise(
      detachVolume(VolumeId(201)).pipe(provide(http))
    )
  })

  it("fails with HcloudVolumeNotFound when volume doesn't exist", async () => {
    const http = mockHttp(
      new Response(JSON.stringify({ error: { message: "Volume not found" } }), { status: 404 }),
    )

    const result = await Effect.runPromiseExit(
      detachVolume(VolumeId(999)).pipe(provide(http))
    )

    expect(Exit.isFailure(result)).toBe(true)
    if (Exit.isFailure(result) && result.cause._tag === "Fail") {
      expect(result.cause.error._tag).toBe("HcloudVolumeNotFound")
    }
  })
})
