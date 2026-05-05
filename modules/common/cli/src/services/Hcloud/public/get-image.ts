import { Effect } from "effect"
import { HttpClient } from "@effect/platform"
import { HcloudImageNotFound, HcloudGetImageError } from "../errors"
import type { Image, ImageId } from "../types"
import { HcloudConfig } from "../config"
import { listImages } from "./list-images"

export const getImage = (nameOrId: string | ImageId) =>
  Effect.gen(function* () {
    const { apiBaseUrl, token: tokenEffect } = yield* HcloudConfig
    if (typeof nameOrId === "number") {
      const client = yield* HttpClient.HttpClient
      const token = yield* tokenEffect
      const id = String(nameOrId)
      const response = yield* client.get(`${apiBaseUrl}/images/${nameOrId}`, {
        headers: { Authorization: `Bearer ${token}` },
      }).pipe(
        Effect.catchTag("RequestError", (e) => Effect.fail(new HcloudGetImageError({ id: nameOrId, message: "Request failed", cause: e }))),
        Effect.catchTag("ResponseError", (e) => Effect.fail(new HcloudGetImageError({ id: nameOrId, message: "HTTP response error", cause: e }))),
      )

      if (response.status === 404) {
        return yield* Effect.fail(new HcloudImageNotFound({ id }))
      }

      const json = (yield* response.json.pipe(
        Effect.catchTag("ResponseError", (e) => Effect.fail(new HcloudGetImageError({ id: nameOrId, message: `Failed to parse API response (HTTP ${response.status})`, cause: e }))),
      )) as { image?: Image; error?: { message: string } }

      if (response.status >= 400 || !json.image) {
        return yield* Effect.fail(new HcloudGetImageError({ id: nameOrId, message: json.error?.message ?? `HTTP ${response.status}` }))
      }

      return json.image
    }

    const images = yield* listImages().pipe(
      Effect.catchTag("HcloudListImagesError", (e) => Effect.fail(new HcloudGetImageError({ id: nameOrId, message: "Failed to list images", cause: e })))
    )
    const image = images.find(i => i.name === nameOrId)
    if (!image) {
      return yield* Effect.fail(new HcloudImageNotFound({ id: nameOrId }))
    }
    return image
  })
