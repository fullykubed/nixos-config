import { Effect } from "effect"
import { HttpBody, HttpClient } from "@effect/platform"
import { HeadscalePreAuthError } from "../errors"
import { HEADSCALE_API_URL, HEADSCALE_USER_ID } from "../config"
import { readHeadscaleApiKey } from "./read-headscale-api-key"

export const mintPreAuthKey = () =>
  Effect.gen(function* () {
    const client = yield* HttpClient.HttpClient
    const apiKey = yield* readHeadscaleApiKey()
    const expiry = new Date(Date.now() + 2 * 60 * 60 * 1000).toISOString()
    const response = yield* client.post(`${HEADSCALE_API_URL}/preauthkey`, {
      headers: { Authorization: `Bearer ${apiKey}` },
      body: HttpBody.unsafeJson({
        user: HEADSCALE_USER_ID,
        reusable: false,
        ephemeral: true,
        expiration: expiry,
      }),
    }).pipe(
      Effect.catchTag("RequestError", () => Effect.fail(new HeadscalePreAuthError({ message: "Failed to reach headscale API" }))),
      Effect.catchTag("ResponseError", () => Effect.fail(new HeadscalePreAuthError({ message: "HTTP response error from headscale API" }))),
    )
    if (response.status >= 400) {
      return yield* Effect.fail(new HeadscalePreAuthError({
        message: `Headscale API returned ${response.status}`
      }))
    }
    const parsed = (yield* response.json.pipe(
      Effect.catchTag("ResponseError", () => Effect.fail(new HeadscalePreAuthError({ message: "Failed to parse headscale pre-auth key response" })))
    )) as { preAuthKey?: { key?: string } }
    const key = parsed.preAuthKey?.key
    if (!key) {
      return yield* Effect.fail(new HeadscalePreAuthError({
        message: "Headscale response did not contain a pre-auth key"
      }))
    }
    return key
  })
