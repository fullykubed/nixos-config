import { Effect } from "effect"
import { defineCommand, type TypedParsed } from "../../../cli/types"

const listFlags = [
  {
    kind: "boolean",
    name: "json",
    description: "Output results as JSON",
    default: false
  }
] as const

const listArgs = [] as const

export type Parsed = TypedParsed<typeof listFlags, typeof listArgs>

export const listCommand = defineCommand({
  name: "list",
  description: "List all active builder VMs",
  flags: listFlags,
  args: listArgs,
  handler: (parsed) =>
    Effect.gen(function* () {
      const [{ listHandler }, { BuildersFullLive }] = yield* Effect.all([
        Effect.promise(() => import("./handler")),
        Effect.promise(() => import("../../../services/layers"))
      ], { concurrency: "unbounded" })
      yield* listHandler(parsed).pipe(Effect.provide(BuildersFullLive))
    })
})
