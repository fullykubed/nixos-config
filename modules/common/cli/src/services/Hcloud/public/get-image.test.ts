import { describe, it, expect } from "bun:test"
import { Context, Effect, Exit } from "effect"
import { HttpClient } from "@effect/platform"
import { getImage } from "./get-image"
import { mockHttp, image1, defaultHcloudConfig } from "../helpers.test"
import { ImageId } from "../types"
import { HcloudConfig } from "../config"

const provide = (http: HttpClient.HttpClient) =>
  Effect.provide(Context.empty().pipe(
    Context.add(HttpClient.HttpClient, http),
    Context.add(HcloudConfig, defaultHcloudConfig),
  ))

describe("getImage", () => {
  it("gets image by ID", async () => {
    const http = mockHttp(
      Response.json({ image: image1 }),
    )

    const result = await Effect.runPromise(
      getImage(ImageId(100)).pipe(provide(http))
    )

    expect(result).toEqual(image1)
  })

  it("gets image by name via list", async () => {
    const http = mockHttp(
      Response.json({
        images: [image1],
        meta: { pagination: { next_page: null } },
      }),
    )

    const result = await Effect.runPromise(
      getImage("builder-snap-1").pipe(provide(http))
    )

    expect(result).toEqual(image1)
  })

  it("fails with HcloudImageNotFound when image not found", async () => {
    const http = mockHttp(
      new Response(JSON.stringify({ error: { message: "Image not found" } }), { status: 404 }),
    )

    const result = await Effect.runPromiseExit(
      getImage(ImageId(999)).pipe(provide(http))
    )

    expect(Exit.isFailure(result)).toBe(true)
    if (Exit.isFailure(result) && result.cause._tag === "Fail") {
      expect(result.cause.error._tag).toBe("HcloudImageNotFound")
    }
  })
})
