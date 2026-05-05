import { describe, it, expect } from "bun:test"
import { Context, Effect } from "effect"
import { HttpClient } from "@effect/platform"
import { imageExists } from "./image-exists"
import { mockHttp, image1, defaultHcloudConfig } from "../helpers.test"
import { ImageId } from "../types"
import { HcloudConfig } from "../config"

const provide = (http: HttpClient.HttpClient) =>
  Effect.provide(Context.empty().pipe(
    Context.add(HttpClient.HttpClient, http),
    Context.add(HcloudConfig, defaultHcloudConfig),
  ))

describe("imageExists", () => {
  it("returns true when image exists", async () => {
    const http = mockHttp(
      Response.json({ image: image1 }),
    )

    const result = await Effect.runPromise(
      imageExists(ImageId(100)).pipe(provide(http))
    )

    expect(result).toBe(true)
  })

  it("returns false when image not found", async () => {
    const http = mockHttp(
      new Response(JSON.stringify({ error: { message: "Image not found" } }), { status: 404 }),
    )

    const result = await Effect.runPromise(
      imageExists(ImageId(999)).pipe(provide(http))
    )

    expect(result).toBe(false)
  })
})
