import { Effect } from "effect"
import { defineCommand, type TypedParsed } from "../../../cli/types"

const destroyFlags = [
  { kind: "boolean", name: "all", short: "a", description: "Destroy all builders", default: false },
  { kind: "boolean", name: "yes", short: "y", description: "Skip confirmation prompt", default: false },
  { kind: "boolean", name: "json", description: "Output results as JSON", default: false }
] as const

const destroyArgs = [{ name: "name", description: "Builder name (optional with -a)", required: false }] as const

export type Parsed = TypedParsed<typeof destroyFlags, typeof destroyArgs>

export const destroyCommand = defineCommand({
  name: "destroy",
  description: "Destroy a builder VM",
  flags: destroyFlags,
  args: destroyArgs,
  handler: (parsed) =>
    Effect.gen(function* () {
      const [{ destroyHandler }, { BuildersFullLive }] = yield* Effect.all([
        Effect.promise(() => import("./destroy-handler")),
        Effect.promise(() => import("../../../services/layers"))
      ], { concurrency: "unbounded" })
      yield* destroyHandler(parsed).pipe(Effect.provide(BuildersFullLive))
    })
})
