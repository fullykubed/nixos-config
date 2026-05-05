import { Effect } from "effect"
import { defineCommand, type TypedParsed } from "../../../cli/types"

const createFlags = [] as const
const createArgs = [{ name: "name", description: "Builder name (e.g., 1, big-1, builder-1)", required: true }] as const

export type Parsed = TypedParsed<typeof createFlags, typeof createArgs>

export const createCommand = defineCommand({
  name: "create",
  description: "Create a new remote builder VM",
  flags: createFlags,
  args: createArgs,
  handler: (parsed) =>
    Effect.gen(function* () {
      const [{ createHandler }, { BuildersFullLive }] = yield* Effect.all([
        Effect.promise(() => import("./handler")),
        Effect.promise(() => import("../../../services/layers"))
      ], { concurrency: "unbounded" })
      yield* createHandler(parsed).pipe(Effect.provide(BuildersFullLive))
    })
})
