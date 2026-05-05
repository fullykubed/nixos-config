import { Effect } from "effect"
import { HttpClient } from "@effect/platform"
import { HcloudVolumeNotFound, HcloudGetVolumeError } from "../errors"
import type { Volume, VolumeId } from "../types"
import { HcloudConfig } from "../config"

export const getVolume = (nameOrId: string | VolumeId) =>
  Effect.gen(function* () {
    const { apiBaseUrl, token: tokenEffect } = yield* HcloudConfig
    const client = yield* HttpClient.HttpClient
    if (typeof nameOrId === "number") {
      const token = yield* tokenEffect
      const name = String(nameOrId)
      const response = yield* client.get(`${apiBaseUrl}/volumes/${nameOrId}`, {
        headers: { Authorization: `Bearer ${token}` },
      }).pipe(
        Effect.catchTag("RequestError", (e) => Effect.fail(new HcloudGetVolumeError({ name, message: "Request failed", cause: e }))),
        Effect.catchTag("ResponseError", (e) => Effect.fail(new HcloudGetVolumeError({ name, message: "HTTP response error", cause: e }))),
      )

      if (response.status === 404) {
        return yield* Effect.fail(new HcloudVolumeNotFound({ name }))
      }

      const json = (yield* response.json.pipe(
        Effect.catchTag("ResponseError", (e) => Effect.fail(new HcloudGetVolumeError({ name, message: `Failed to parse API response (HTTP ${response.status})`, cause: e }))),
      )) as { volume?: Volume; error?: { message: string } }

      if (response.status >= 400 || !json.volume) {
        return yield* Effect.fail(new HcloudGetVolumeError({ name, message: json.error?.message ?? `HTTP ${response.status}` }))
      }

      return json.volume
    }

    const token = yield* tokenEffect
    const params = new URLSearchParams({ name: nameOrId, per_page: "1" })
    const response = yield* client.get(`${apiBaseUrl}/volumes?${params.toString()}`, {
      headers: { Authorization: `Bearer ${token}` },
    }).pipe(
      Effect.catchTag("RequestError", (e) => Effect.fail(new HcloudGetVolumeError({ name: nameOrId, message: "Request failed", cause: e }))),
      Effect.catchTag("ResponseError", (e) => Effect.fail(new HcloudGetVolumeError({ name: nameOrId, message: "HTTP response error", cause: e }))),
    )

    const json = (yield* response.json.pipe(
      Effect.catchTag("ResponseError", (e) => Effect.fail(new HcloudGetVolumeError({ name: nameOrId, message: `Failed to parse API response (HTTP ${response.status})`, cause: e }))),
    )) as { volumes: Volume[] }

    const volume = json.volumes.find(v => v.name === nameOrId)
    if (!volume) {
      return yield* Effect.fail(new HcloudVolumeNotFound({ name: nameOrId }))
    }
    return volume
  })
