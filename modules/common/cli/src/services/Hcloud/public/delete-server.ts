import { Effect, Schedule } from "effect"
import { HttpClient } from "@effect/platform"
import { HcloudDeleteServerError } from "../errors"
import { getServer } from "./get-server"
import { HcloudConfig } from "../config"

export const deleteServer = (name: string, opts?: { wait?: boolean }) =>
  Effect.gen(function* () {
    const server = yield* getServer(name).pipe(
      Effect.catchTag("HcloudGetServerError", (e) => Effect.fail(new HcloudDeleteServerError({ name, message: "Failed to look up server", cause: e })))
    )

    if (server.status !== "deleting") {
      const { apiBaseUrl, token: tokenEffect } = yield* HcloudConfig
      const client = yield* HttpClient.HttpClient
      const token = yield* tokenEffect
      const serverId = server.id

      const deleteResponse = yield* client.del(`${apiBaseUrl}/servers/${serverId}`, {
        headers: { Authorization: `Bearer ${token}` },
      }).pipe(
        Effect.catchTag("RequestError", (e) => Effect.fail(new HcloudDeleteServerError({ name, message: "Request failed", cause: e }))),
        Effect.catchTag("ResponseError", (e) => Effect.fail(new HcloudDeleteServerError({ name, message: "HTTP response error", cause: e }))),
      )

      if (deleteResponse.status >= 400) {
        const errorJson = (yield* deleteResponse.json.pipe(
          Effect.catchTag("ResponseError", (e) => Effect.fail(new HcloudDeleteServerError({ name, message: `HTTP ${deleteResponse.status}`, cause: e }))),
        )) as { error?: { message: string } }
        return yield* Effect.fail(new HcloudDeleteServerError({
          name,
          message: errorJson.error?.message ?? `HTTP ${deleteResponse.status}`,
        }))
      }
    }

    if (!opts?.wait) return

    // Poll until the server is gone
    yield* getServer(name).pipe(
      Effect.flatMap(() => Effect.fail("still exists" as const)),
      Effect.catchTag("HcloudServerNotFound", () => Effect.void),
      Effect.catchTag("HcloudGetServerError", () => Effect.fail("still exists" as const)),
      Effect.retry(Schedule.spaced("3 seconds").pipe(Schedule.upTo("120 seconds"))),
      Effect.catchAll(() => Effect.fail(new HcloudDeleteServerError({
        name,
        message: "Server did not disappear within 120s",
      }))),
    )
  }).pipe(Effect.asVoid)
