import { Effect } from "effect"
import { HttpClient } from "@effect/platform"
import { HcloudDeleteImageError } from "../errors"
import type { ImageId } from "../types"
import { HcloudConfig } from "../config"
import { getImage } from "./get-image"

export const deleteImage = (nameOrId: string | ImageId) =>
  Effect.gen(function* () {
    const { apiBaseUrl, token: tokenEffect } = yield* HcloudConfig
    const image = yield* getImage(nameOrId).pipe(
      Effect.catchTag("HcloudGetImageError", (e) => Effect.fail(new HcloudDeleteImageError({ id: nameOrId, message: "Failed to look up image", cause: e })))
    )

    const client = yield* HttpClient.HttpClient
    const token = yield* tokenEffect
    const response = yield* client.del(`${apiBaseUrl}/images/${image.id}`, {
      headers: { Authorization: `Bearer ${token}` },
    }).pipe(
      Effect.catchTag("RequestError", (e) => Effect.fail(new HcloudDeleteImageError({ id: nameOrId, message: "Request failed", cause: e }))),
      Effect.catchTag("ResponseError", (e) => Effect.fail(new HcloudDeleteImageError({ id: nameOrId, message: "HTTP response error", cause: e }))),
    )

    if (response.status >= 400) {
      const errorJson = (yield* response.json.pipe(
        Effect.catchTag("ResponseError", (e) => Effect.fail(new HcloudDeleteImageError({ id: nameOrId, message: `HTTP ${response.status}`, cause: e }))),
      )) as { error?: { message: string } }
      return yield* Effect.fail(new HcloudDeleteImageError({
        id: nameOrId,
        message: errorJson.error?.message ?? `HTTP ${response.status}`,
      }))
    }
  }).pipe(Effect.asVoid)
