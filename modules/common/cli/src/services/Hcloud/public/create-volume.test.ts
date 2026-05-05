import { describe, it, expect } from "bun:test"
import { Context, Effect, Exit } from "effect"
import { HttpClient } from "@effect/platform"
import { createVolume } from "./create-volume"
import { mockHttp, volume1, defaultHcloudConfig } from "../test-helpers"
import type { CreateVolumeOptions } from "../types"
import { HcloudConfig } from "../config"

const provide = (http: HttpClient.HttpClient) =>
  Effect.provide(Context.empty().pipe(
    Context.add(HttpClient.HttpClient, http),
    Context.add(HcloudConfig, defaultHcloudConfig),
  ))

describe("createVolume", () => {
  it("creates volume with minimal options", async () => {
    const http = mockHttp(
      new Response(JSON.stringify({ volume: volume1 }), { status: 201 }),
    )

    const opts: CreateVolumeOptions = {
      name: "ccache-builder-1",
      size: 50,
      location: "fsn1",
    }

    const result = await Effect.runPromise(
      createVolume(opts).pipe(provide(http))
    )

    expect(result).toEqual(volume1)
  })

  it("fails with HcloudCreateVolumeError on HTTP error", async () => {
    const http = mockHttp(
      new Response(JSON.stringify({ error: { message: "Invalid volume size" } }), { status: 400 }),
    )

    const opts: CreateVolumeOptions = {
      name: "test-volume",
      size: -1,
      location: "fsn1",
    }

    const result = await Effect.runPromiseExit(
      createVolume(opts).pipe(provide(http))
    )

    expect(Exit.isFailure(result)).toBe(true)
    if (Exit.isFailure(result) && result.cause._tag === "Fail") {
      expect(result.cause.error._tag).toBe("HcloudCreateVolumeError")
      expect((result.cause.error as { message: string }).message).toBe("Invalid volume size")
    }
  })
})
