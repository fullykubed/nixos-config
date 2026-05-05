import { Effect, Schedule } from "effect"
import { HttpBody, HttpClient } from "@effect/platform"
import { HcloudCreateServerError } from "../errors"
import type { Server, CreateServerOptions } from "../types"
import { HcloudConfig } from "../config"

export const createServer = (opts: CreateServerOptions) =>
  Effect.gen(function* () {
    const { apiBaseUrl, token: tokenEffect } = yield* HcloudConfig
    const client = yield* HttpClient.HttpClient
    const token = yield* tokenEffect

    const body: Record<string, unknown> = {
      name: opts.name,
      server_type: opts.type,
      location: opts.location,
      image: opts.image,
    }
    if (opts.sshKeys && opts.sshKeys.length > 0) body.ssh_keys = [...opts.sshKeys]
    if (opts.userData) body.user_data = opts.userData
    if (opts.volumes && opts.volumes.length > 0) body.volumes = [...opts.volumes]
    if (opts.labels) body.labels = opts.labels

    const response = yield* client.post(`${apiBaseUrl}/servers`, {
      headers: { Authorization: `Bearer ${token}` },
      body: HttpBody.unsafeJson(body),
    }).pipe(
      Effect.catchTag("RequestError", (e) => Effect.fail(new HcloudCreateServerError({ name: opts.name, message: "Request failed", cause: e }))),
      Effect.catchTag("ResponseError", (e) => Effect.fail(new HcloudCreateServerError({ name: opts.name, message: "Response error", cause: e }))),
    )

    const json = (yield* response.json.pipe(
      Effect.catchTag("ResponseError", (e) => Effect.fail(new HcloudCreateServerError({ name: opts.name, message: `Failed to parse API response (HTTP ${response.status})`, cause: e }))),
    )) as { server?: Server; error?: { message: string; code: string } }

    if (response.status >= 400 || !json.server) {
      return yield* Effect.fail(new HcloudCreateServerError({
        name: opts.name,
        message: json.error?.message ?? `HTTP ${response.status}`,
      }))
    }

    if (!opts.waitForRunning) return json.server

    // Poll GET /v1/servers/{id} until status is "running"
    const serverId = json.server.id
    const pollOnce = Effect.gen(function* () {
      const pollResponse = yield* client.get(`${apiBaseUrl}/servers/${serverId}`, {
        headers: { Authorization: `Bearer ${token}` },
      }).pipe(
        Effect.catchTag("RequestError", (e) => Effect.fail(new HcloudCreateServerError({ name: opts.name, message: "Poll request failed", cause: e }))),
        Effect.catchTag("ResponseError", (e) => Effect.fail(new HcloudCreateServerError({ name: opts.name, message: "Poll response error", cause: e }))),
      )

      const pollJson = (yield* pollResponse.json.pipe(
        Effect.catchTag("ResponseError", (e) => Effect.fail(new HcloudCreateServerError({ name: opts.name, message: `Failed to parse poll response (HTTP ${pollResponse.status})`, cause: e }))),
      )) as { server?: Server }

      if (pollJson.server?.status !== "running") {
        return yield* Effect.fail(new HcloudCreateServerError({ name: opts.name, message: "Not running yet" }))
      }
      return pollJson.server
    })

    return yield* pollOnce.pipe(
      Effect.retry(Schedule.spaced("5 seconds").pipe(Schedule.intersect(Schedule.recurs(59)))),
      Effect.catchTag("HcloudCreateServerError", () => Effect.fail(new HcloudCreateServerError({
        name: opts.name,
        message: `Server did not reach 'running' status within 300s`,
      })))
    )
  })
