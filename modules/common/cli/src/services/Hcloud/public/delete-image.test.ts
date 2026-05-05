import { describe, it, expect } from "bun:test"
import { Context, Effect, Exit } from "effect"
import { HttpClient } from "@effect/platform"
import { deleteImage } from "./delete-image"
import { mockHttp, image1, defaultHcloudConfig } from "../helpers.test"
import { ImageId } from "../types"
import { HcloudConfig } from "../config"

const provide = (http: HttpClient.HttpClient) =>
  Effect.provide(Context.empty().pipe(
    Context.add(HttpClient.HttpClient, http),
    Context.add(HcloudConfig, defaultHcloudConfig),
  ))

describe("deleteImage", () => {
  it("deletes image by ID", async () => {
    const http = mockHttp(
      // getImage response
      Response.json({ image: image1 }),
      // delete response
      new Response(null, { status: 204 }),
    )

    await Effect.runPromise(
      deleteImage(ImageId(100)).pipe(provide(http))
    )
  })

  it("fails with HcloudImageNotFound when image doesn't exist", async () => {
    const http = mockHttp(
      new Response(JSON.stringify({ error: { message: "Image not found" } }), { status: 404 }),
    )

    const result = await Effect.runPromiseExit(
      deleteImage(ImageId(999)).pipe(provide(http))
    )

    expect(Exit.isFailure(result)).toBe(true)
    if (Exit.isFailure(result) && result.cause._tag === "Fail") {
      expect(result.cause.error._tag).toBe("HcloudImageNotFound")
    }
  })
})
