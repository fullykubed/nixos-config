import { Effect } from "effect"
import type { ParsedCommand } from "../../../cli/types"
import { BuildersService } from "../../../services/Builders"
import { table, json } from "../../../lib/output"
import type { Builder } from "../types"

export const listHandler = (parsed: ParsedCommand) =>
  Effect.gen(function* () {
    const builders = yield* BuildersService
    const isJson = parsed.flags.get("json") === true

    const servers = yield* builders.list()

    const builderList = servers.map((server): Builder => ({
      name: server.name,
      status: server.status,
      serverType: server.server_type.name,
      publicIp: server.public_net.ipv4.ip,
      created: server.created
    }))

    // Handle empty list
    if (builderList.length === 0) {
      if (isJson) {
        json([])
      } else {
        yield* Effect.log("No active builders")
      }
      return
    }

    // Output in requested format
    if (isJson) {
      json(builderList)
    } else {
      const headers = ["NAME", "STATUS", "TYPE", "IP", "CREATED"]
      const rows = builderList.map(builder => [
        builder.name,
        builder.status,
        builder.serverType,
        builder.publicIp,
        builder.created
      ])

      table(headers, rows)
    }
  })
