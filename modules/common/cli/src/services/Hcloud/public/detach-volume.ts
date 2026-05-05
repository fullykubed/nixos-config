import { Effect } from "effect"
import { HttpClient } from "@effect/platform"
import { HcloudDetachVolumeError } from "../errors"
import type { VolumeId } from "../types"
import { HcloudConfig } from "../config"
import { getVolume } from "./get-volume"

export const detachVolume = (nameOrId: string | VolumeId) =>
  Effect.gen(function* () {
    const displayName = String(nameOrId)
    const volume = yield* getVolume(nameOrId).pipe(
      Effect.catchTag("HcloudGetVolumeError", (e) => Effect.fail(new HcloudDetachVolumeError({ name: displayName, message: "Failed to look up volume", cause: e })))
    )

    const { apiBaseUrl, token: tokenEffect } = yield* HcloudConfig
    const client = yield* HttpClient.HttpClient
    const token = yield* tokenEffect
    const response = yield* client.post(`${apiBaseUrl}/volumes/${volume.id}/actions/detach`, {
      headers: { Authorization: `Bearer ${token}` },
    }).pipe(
      Effect.catchTag("RequestError", (e) => Effect.fail(new HcloudDetachVolumeError({ name: displayName, message: "Request failed", cause: e }))),
      Effect.catchTag("ResponseError", (e) => Effect.fail(new HcloudDetachVolumeError({ name: displayName, message: "HTTP response error", cause: e }))),
    )

    if (response.status >= 400) {
      const errorJson = (yield* response.json.pipe(
        Effect.catchTag("ResponseError", (e) => Effect.fail(new HcloudDetachVolumeError({ name: displayName, message: `HTTP ${response.status}`, cause: e }))),
      )) as { error?: { message: string } }
      return yield* Effect.fail(new HcloudDetachVolumeError({
        name: displayName,
        message: errorJson.error?.message ?? `HTTP ${response.status}`,
      }))
    }
  }).pipe(Effect.asVoid)
