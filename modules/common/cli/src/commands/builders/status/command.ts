import { Effect } from "effect"
import { defineCommand, type TypedParsed } from "../../../cli/types"

const statusFlags = [
  {
    kind: "boolean",
    name: "json",
    description: "Output in JSON format",
    default: false
  }
] as const

const statusArgs = [] as const

export type Parsed = TypedParsed<typeof statusFlags, typeof statusArgs>

export const statusCommand = defineCommand({
  name: "status",
  description: "Show builder status summary with cost breakdown",
  flags: statusFlags,
  args: statusArgs,
  handler: (parsed) =>
    Effect.gen(function* () {
      const [{ statusHandler }, { BuildersFullLive }] = yield* Effect.all([
        Effect.promise(() => import("./handler")),
        Effect.promise(() => import("../../../services/layers"))
      ], { concurrency: "unbounded" })
      yield* statusHandler(parsed).pipe(Effect.provide(BuildersFullLive))
    })
})
