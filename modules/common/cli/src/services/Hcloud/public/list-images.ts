import { Effect } from "effect"
import { HttpClient } from "@effect/platform"
import { HcloudListImagesError } from "../errors"
import type { Image } from "../types"
import { HcloudConfig } from "../config"

export const listImages = (type?: string, labels?: Record<string, string>) =>
  Effect.gen(function* () {
    const { apiBaseUrl, token: tokenEffect } = yield* HcloudConfig
    const client = yield* HttpClient.HttpClient
    const token = yield* tokenEffect
    const images: Image[] = []
    let page = 1

    const params = new URLSearchParams({ per_page: "50" })
    if (type) params.set("type", type)
    if (labels) {
      params.set("label_selector", Object.entries(labels).map(([k, v]) => `${k}=${v}`).join(","))
    }

    // eslint-disable-next-line @typescript-eslint/no-unnecessary-condition -- pagination loop
    while (true) {
      params.set("page", String(page))
      const response = yield* client.get(`${apiBaseUrl}/images?${params.toString()}`, {
        headers: { Authorization: `Bearer ${token}` },
      }).pipe(
        Effect.catchTag("RequestError", (e) => Effect.fail(new HcloudListImagesError({ message: "Request failed", cause: e }))),
        Effect.catchTag("ResponseError", (e) => Effect.fail(new HcloudListImagesError({ message: "HTTP response error", cause: e }))),
      )

      if (response.status >= 400) {
        return yield* Effect.fail(new HcloudListImagesError({ message: `HTTP ${response.status}` }))
      }

      const json = (yield* response.json.pipe(
        Effect.catchTag("ResponseError", (e) => Effect.fail(new HcloudListImagesError({ message: `Failed to parse API response (HTTP ${response.status})`, cause: e }))),
      )) as {
        images: Image[]
        meta: { pagination: { next_page: number | null } }
      }

      images.push(...json.images)

      if (json.meta.pagination.next_page === null) break
      page = json.meta.pagination.next_page
    }

    return images
  })
