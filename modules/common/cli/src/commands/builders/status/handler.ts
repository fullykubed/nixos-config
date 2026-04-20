import { Effect } from "effect"
import type { ParsedCommand } from "../../../cli/types"
import { BuildersService, BUILDER_CONFIG, builderType } from "../../../services/Builders"
import { json } from "../../../lib/output"
import type { BuilderSummary, BuilderDetails, StatusOutput } from "./types"
import { calculateUptimeHours } from "../../../services/Builders/calculate-uptime"
import { formatCost } from "./format-cost"

export const statusHandler = (parsed: ParsedCommand) => Effect.gen(function* () {
  const builders = yield* BuildersService
  const servers = yield* builders.list()

  // Split into regular and big builders
  const regularBuilders = servers.filter(s => builderType(s.name) === "regular")
  const bigBuilders = servers.filter(s => builderType(s.name) === "big")

  // Calculate costs
  const regularCost = regularBuilders.length * BUILDER_CONFIG.regularCostPerHour
  const bigCost = bigBuilders.length * BUILDER_CONFIG.bigCostPerHour
  const totalCost = regularCost + bigCost

  const summary: BuilderSummary = {
    regularCount: regularBuilders.length,
    bigCount: bigBuilders.length,
    totalCount: servers.length,
    regularCost,
    bigCost,
    totalCost
  }

  // Build detailed builder info
  const builderDetails: BuilderDetails[] = servers
    .map(server => {
      const cost = builderType(server.name) === "big"
        ? BUILDER_CONFIG.bigCostPerHour
        : BUILDER_CONFIG.regularCostPerHour
      const uptime = calculateUptimeHours(server.created)
      return {
        name: server.name,
        status: server.status,
        ip: server.public_net.ipv4.ip,
        serverType: server.server_type.name,
        uptimeHours: uptime,
        costPerHour: cost,
        totalCost: uptime * cost,
      }
    })

  const output: StatusOutput = {
    summary,
    builders: builderDetails
  }

  // Handle JSON output
  if (parsed.flags.get("json") === true) {
    json(output)
    return
  }

  // Human-readable output
  yield* Effect.log("Builder Status Summary")
  yield* Effect.log("========================")
  yield* Effect.log(`Regular builders:      ${summary.regularCount}  (${BUILDER_CONFIG.regularServerType} @ ~${formatCost(BUILDER_CONFIG.regularCostPerHour)}/hr)`)
  yield* Effect.log(`Big-parallel builders: ${summary.bigCount}  (${BUILDER_CONFIG.bigServerType} @ ~${formatCost(BUILDER_CONFIG.bigCostPerHour)}/hr)`)
  yield* Effect.log(`Total hourly cost: ${formatCost(summary.totalCost)}`)
  yield* Effect.log("")

  if (summary.totalCount > 0) {
    yield* Effect.log("Builders:")
    for (const builder of builderDetails) {
      yield* Effect.log(`  ${builder.name.padEnd(16)} ${builder.status.padEnd(8)} ${builder.ip}`)
    }
  }
})
