import { Effect } from "effect"
import { HttpClient } from "@effect/platform"
import { HcloudListVolumesError } from "../errors"
import type { Volume } from "../types"
import { HcloudConfig } from "../config"

export const listVolumes = () =>
  Effect.gen(function* () {
    const { apiBaseUrl, token: tokenEffect } = yield* HcloudConfig
    const client = yield* HttpClient.HttpClient
    const token = yield* tokenEffect
    const volumes: Volume[] = []
    let page = 1

    const params = new URLSearchParams({ per_page: "50" })

    // eslint-disable-next-line @typescript-eslint/no-unnecessary-condition -- pagination loop
    while (true) {
      params.set("page", String(page))
      const response = yield* client.get(`${apiBaseUrl}/volumes?${params.toString()}`, {
        headers: { Authorization: `Bearer ${token}` },
      }).pipe(
        Effect.catchTag("RequestError", (e) => Effect.fail(new HcloudListVolumesError({ message: "Request failed", cause: e }))),
        Effect.catchTag("ResponseError", (e) => Effect.fail(new HcloudListVolumesError({ message: "HTTP response error", cause: e }))),
      )

      if (response.status >= 400) {
        return yield* Effect.fail(new HcloudListVolumesError({ message: `HTTP ${response.status}` }))
      }

      const json = (yield* response.json.pipe(
        Effect.catchTag("ResponseError", (e) => Effect.fail(new HcloudListVolumesError({ message: `Failed to parse API response (HTTP ${response.status})`, cause: e }))),
      )) as {
        volumes: Volume[]
        meta: { pagination: { next_page: number | null } }
      }

      volumes.push(...json.volumes)

      if (json.meta.pagination.next_page === null) break
      page = json.meta.pagination.next_page
    }

    return volumes
  })
