import { Effect } from "effect"
import { HttpBody, HttpClient } from "@effect/platform"
import { HcloudCreateVolumeError } from "../errors"
import type { Volume, CreateVolumeOptions } from "../types"
import { HcloudConfig } from "../config"

export const createVolume = (opts: CreateVolumeOptions) =>
  Effect.gen(function* () {
    const { apiBaseUrl, token: tokenEffect } = yield* HcloudConfig
    const client = yield* HttpClient.HttpClient
    const token = yield* tokenEffect

    const body: Record<string, unknown> = {
      name: opts.name,
      size: opts.size,
      location: opts.location,
    }
    if (opts.format) body.format = opts.format
    if (opts.labels) body.labels = opts.labels

    const response = yield* client.post(`${apiBaseUrl}/volumes`, {
      headers: { Authorization: `Bearer ${token}` },
      body: HttpBody.unsafeJson(body),
    }).pipe(
      Effect.catchTag("RequestError", (e) => Effect.fail(new HcloudCreateVolumeError({ name: opts.name, message: "Request failed", cause: e }))),
      Effect.catchTag("ResponseError", (e) => Effect.fail(new HcloudCreateVolumeError({ name: opts.name, message: "HTTP response error", cause: e }))),
    )

    const json = (yield* response.json.pipe(
      Effect.catchTag("ResponseError", (e) => Effect.fail(new HcloudCreateVolumeError({ name: opts.name, message: `Failed to parse API response (HTTP ${response.status})`, cause: e }))),
    )) as { volume?: Volume; error?: { message: string } }

    if (response.status >= 400 || !json.volume) {
      return yield* Effect.fail(new HcloudCreateVolumeError({
        name: opts.name,
        message: json.error?.message ?? `HTTP ${response.status}`,
      }))
    }

    return json.volume
  })
