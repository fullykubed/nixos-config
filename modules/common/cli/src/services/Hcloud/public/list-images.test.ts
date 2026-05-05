import { describe, it, expect } from "bun:test"
import { Context, Effect, Exit } from "effect"
import { HttpClient } from "@effect/platform"
import { listImages } from "./list-images"
import { mockHttp, failHttp, image1, image2, defaultHcloudConfig } from "../helpers.test"
import { HcloudConfig } from "../config"

const provide = (http: HttpClient.HttpClient) =>
  Effect.provide(Context.empty().pipe(
    Context.add(HttpClient.HttpClient, http),
    Context.add(HcloudConfig, defaultHcloudConfig),
  ))

describe("listImages", () => {
  it("returns empty list when no images exist", async () => {
    const http = mockHttp(
      Response.json({
        images: [],
        meta: { pagination: { next_page: null } },
      }),
    )

    const result = await Effect.runPromise(
      listImages().pipe(provide(http))
    )

    expect(result).toEqual([])
  })

  it("returns images from single page", async () => {
    const http = mockHttp(
      Response.json({
        images: [image1, image2],
        meta: { pagination: { next_page: null } },
      }),
    )

    const result = await Effect.runPromise(
      listImages().pipe(provide(http))
    )

    expect(result).toEqual([image1, image2])
  })

  it("handles pagination correctly", async () => {
    const http = mockHttp(
      Response.json({
        images: [image1],
        meta: { pagination: { next_page: 2 } },
      }),
      Response.json({
        images: [image2],
        meta: { pagination: { next_page: null } },
      }),
    )

    const result = await Effect.runPromise(
      listImages().pipe(provide(http))
    )

    expect(result).toEqual([image1, image2])
  })

  it("applies type filter", async () => {
    const http = mockHttp(
      Response.json({
        images: [image1, image2],
        meta: { pagination: { next_page: null } },
      }),
    )

    const result = await Effect.runPromise(
      listImages("snapshot").pipe(provide(http))
    )

    expect(result).toEqual([image1, image2])
  })

  it("applies labels filter", async () => {
    const http = mockHttp(
      Response.json({
        images: [image1, image2],
        meta: { pagination: { next_page: null } },
      }),
    )

    const result = await Effect.runPromise(
      listImages(undefined, { type: "builder" }).pipe(provide(http))
    )

    expect(result).toEqual([image1, image2])
  })

  it("fails with HcloudListImagesError on HTTP error", async () => {
    const http = mockHttp(
      new Response(JSON.stringify({ error: { message: "Internal server error" } }), { status: 500 }),
    )

    const result = await Effect.runPromiseExit(
      listImages().pipe(provide(http))
    )

    expect(Exit.isFailure(result)).toBe(true)
    if (Exit.isFailure(result) && result.cause._tag === "Fail") {
      expect(result.cause.error._tag).toBe("HcloudListImagesError")
      expect((result.cause.error as { message: string }).message).toBe("HTTP 500")
    }
  })

  it("fails with HcloudListImagesError on network error", async () => {
    const result = await Effect.runPromiseExit(
      listImages().pipe(provide(failHttp))
    )

    expect(Exit.isFailure(result)).toBe(true)
    if (Exit.isFailure(result) && result.cause._tag === "Fail") {
      expect(result.cause.error._tag).toBe("HcloudListImagesError")
      expect((result.cause.error as { message: string }).message).toBe("Request failed")
    }
  })
})
