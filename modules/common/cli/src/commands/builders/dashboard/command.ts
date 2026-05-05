import { Effect } from "effect"
import { defineCommand, type TypedParsed } from "../../../cli/types"

const dashboardFlags = [] as const
const dashboardArgs = [] as const

export type Parsed = TypedParsed<typeof dashboardFlags, typeof dashboardArgs>

export const dashboardCommand = defineCommand({
  name: "dashboard",
  description: "Live-updating resource dashboard for all builders",
  flags: dashboardFlags,
  args: dashboardArgs,
  handler: (parsed) =>
    Effect.gen(function* () {
      const [{ dashboardHandler }, { BuildersFullLive }] = yield* Effect.all([
        Effect.promise(() => import("./handler")),
        Effect.promise(() => import("../../../services/layers"))
      ], { concurrency: "unbounded" })
      yield* dashboardHandler(parsed).pipe(Effect.provide(BuildersFullLive))
    })
})
