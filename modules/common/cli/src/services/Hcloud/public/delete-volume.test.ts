import { describe, it, expect } from "bun:test"
import { Context, Effect, Exit } from "effect"
import { HttpClient } from "@effect/platform"
import { deleteVolume } from "./delete-volume"
import { mockHttp, volume1, defaultHcloudConfig } from "../test-helpers"
import { VolumeId } from "../types"
import { HcloudConfig } from "../config"

const provide = (http: HttpClient.HttpClient) =>
  Effect.provide(Context.empty().pipe(
    Context.add(HttpClient.HttpClient, http),
    Context.add(HcloudConfig, defaultHcloudConfig),
  ))

describe("deleteVolume", () => {
  it("deletes volume by ID", async () => {
    const http = mockHttp(
      // getVolume response
      Response.json({ volume: volume1 }),
      // delete response
      new Response(null, { status: 204 }),
    )

    await Effect.runPromise(
      deleteVolume(VolumeId(200)).pipe(provide(http))
    )
  })

  it("fails with HcloudVolumeNotFound when volume doesn't exist", async () => {
    const http = mockHttp(
      new Response(JSON.stringify({ error: { message: "Volume not found" } }), { status: 404 }),
    )

    const result = await Effect.runPromiseExit(
      deleteVolume(VolumeId(999)).pipe(provide(http))
    )

    expect(Exit.isFailure(result)).toBe(true)
    if (Exit.isFailure(result) && result.cause._tag === "Fail") {
      expect(result.cause.error._tag).toBe("HcloudVolumeNotFound")
    }
  })
})
