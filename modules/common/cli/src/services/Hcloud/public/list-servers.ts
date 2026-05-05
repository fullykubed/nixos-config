import { Effect } from "effect"
import { HttpClient } from "@effect/platform"
import { HcloudListServersError } from "../errors"
import type { Server } from "../types"
import { HcloudConfig } from "../config"

export const listServers = (opts?: {
  name?: string; status?: Server["status"]; labels?: Record<string, string>
}) =>
  Effect.gen(function* () {
    const { apiBaseUrl, token: tokenEffect } = yield* HcloudConfig
    const client = yield* HttpClient.HttpClient
    const token = yield* tokenEffect
    const servers: Server[] = []
    let page = 1

    const params = new URLSearchParams({ per_page: "50" })
    if (opts?.name) params.set("name", opts.name)
    if (opts?.status) params.set("status", opts.status)
    if (opts?.labels) {
      params.set("label_selector", Object.entries(opts.labels).map(([k, v]) => `${k}=${v}`).join(","))
    }

    // eslint-disable-next-line @typescript-eslint/no-unnecessary-condition -- pagination loop
    while (true) {
      params.set("page", String(page))
      const response = yield* client.get(`${apiBaseUrl}/servers?${params.toString()}`, {
        headers: { Authorization: `Bearer ${token}` },
      }).pipe(
        Effect.catchTag("RequestError", (e) => Effect.fail(new HcloudListServersError({ message: "Request failed", cause: e }))),
        Effect.catchTag("ResponseError", (e) => Effect.fail(new HcloudListServersError({ message: "HTTP response error", cause: e }))),
      )

      if (response.status >= 400) {
        return yield* Effect.fail(new HcloudListServersError({ message: `HTTP ${response.status}` }))
      }

      const json = (yield* response.json.pipe(
        Effect.catchTag("ResponseError", (e) => Effect.fail(new HcloudListServersError({ message: `Failed to parse API response (HTTP ${response.status})`, cause: e }))),
      )) as {
        servers: Server[]
        meta: { pagination: { next_page: number | null } }
      }

      servers.push(...json.servers)

      if (json.meta.pagination.next_page === null) break
      page = json.meta.pagination.next_page
    }

    return servers
  })
