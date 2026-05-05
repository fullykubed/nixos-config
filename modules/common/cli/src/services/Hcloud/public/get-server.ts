import { Effect } from "effect"
import { HttpClient } from "@effect/platform"
import { HcloudServerNotFound, HcloudGetServerError } from "../errors"
import type { Server, ServerId } from "../types"
import { HcloudConfig } from "../config"
import { listServers } from "./list-servers"

export const getServer = (nameOrId: string | ServerId) =>
  Effect.gen(function* () {
    const { apiBaseUrl, token: tokenEffect } = yield* HcloudConfig
    if (typeof nameOrId === "number") {
      const client = yield* HttpClient.HttpClient
      const token = yield* tokenEffect
      const name = String(nameOrId)
      const response = yield* client.get(`${apiBaseUrl}/servers/${nameOrId}`, {
        headers: { Authorization: `Bearer ${token}` },
      }).pipe(
        Effect.catchTag("RequestError", (e) => Effect.fail(new HcloudGetServerError({ name, message: "Request failed", cause: e }))),
        Effect.catchTag("ResponseError", (e) => Effect.fail(new HcloudGetServerError({ name, message: "HTTP response error", cause: e }))),
      )

      if (response.status === 404) {
        return yield* Effect.fail(new HcloudServerNotFound({ name }))
      }

      const json = (yield* response.json.pipe(
        Effect.catchTag("ResponseError", (e) => Effect.fail(new HcloudGetServerError({ name, message: `Failed to parse API response (HTTP ${response.status})`, cause: e }))),
      )) as { server?: Server; error?: { message: string } }

      if (response.status >= 400 || !json.server) {
        return yield* Effect.fail(new HcloudGetServerError({ name, message: json.error?.message ?? `HTTP ${response.status}` }))
      }

      return json.server
    }

    const servers = yield* listServers({ name: nameOrId }).pipe(
      Effect.catchTag("HcloudListServersError", (e) => Effect.fail(new HcloudGetServerError({ name: nameOrId, message: "Failed to list servers", cause: e })))
    )
    const server = servers.find(s => s.name === nameOrId)
    if (!server) {
      return yield* Effect.fail(new HcloudServerNotFound({ name: nameOrId }))
    }
    return server
  })
