import { Effect } from "effect"
import { HttpClient } from "@effect/platform"
import { HeadscaleNodeError } from "../errors"
import { HEADSCALE_API_URL } from "../config"
import { readHeadscaleApiKey } from "./read-headscale-api-key"

export const deleteNode = (hostname: string) =>
  Effect.gen(function* () {
    const apiKey = yield* readHeadscaleApiKey().pipe(
      Effect.catchAll(() =>
        Effect.logWarning("Headscale API key not found, skipping node cleanup").pipe(
          Effect.map(() => "")
        )
      )
    )
    if (!apiKey) return

    const client = yield* HttpClient.HttpClient
    const headers = { Authorization: `Bearer ${apiKey}` }

    const listResponse = yield* client.get(`${HEADSCALE_API_URL}/node`, { headers }).pipe(
      Effect.catchTag("RequestError", () => Effect.fail(new HeadscaleNodeError({ hostname, message: "Failed to reach headscale API" }))),
      Effect.catchTag("ResponseError", () => Effect.fail(new HeadscaleNodeError({ hostname, message: "HTTP response error from headscale API" }))),
    )

    if (listResponse.status >= 400) {
      yield* Effect.logWarning(`Failed to list headscale nodes (${listResponse.status}), skipping node cleanup`)
      return
    }

    interface HeadscaleNode { id: string; givenName?: string; name?: string }
    const nodesData = (yield* listResponse.json.pipe(
      Effect.catchTag("ResponseError", () => Effect.fail(new HeadscaleNodeError({ hostname, message: "Failed to parse headscale nodes response" }))),
      Effect.catchAll(() => Effect.succeed({ nodes: [] as HeadscaleNode[] })),
    )) as { nodes: HeadscaleNode[] }

    const node = nodesData.nodes.find((n: HeadscaleNode) =>
      n.givenName === hostname || n.name === hostname
    )

    if (!node) {
      yield* Effect.logWarning(`No headscale node found for ${hostname} (may already be cleaned up)`)
      return
    }

    const deleteResponse = yield* client.del(`${HEADSCALE_API_URL}/node/${node.id}`, { headers }).pipe(
      Effect.catchTag("RequestError", () => Effect.fail(new HeadscaleNodeError({ hostname, message: `Failed to delete headscale node ${node.id}` }))),
      Effect.catchTag("ResponseError", () => Effect.fail(new HeadscaleNodeError({ hostname, message: `HTTP response error when deleting node ${node.id}` }))),
    )

    if (deleteResponse.status < 400) {
      yield* Effect.log(`Removed ${hostname} from headscale (node ${node.id})`)
    } else {
      yield* Effect.logWarning(`Failed to delete headscale node ${node.id} for ${hostname}`)
    }
  })
