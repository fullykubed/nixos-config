import { Effect } from "effect"
import { defineCommand, type TypedParsed } from "../../../cli/types"

const pollStatusFlags = [] as const
const pollStatusArgs = [] as const

export type Parsed = TypedParsed<typeof pollStatusFlags, typeof pollStatusArgs>

export const pollStatusCommand = defineCommand({
  name: "poll-status",
  description: "Poll builder metrics and write status JSON (systemd oneshot)",
  flags: pollStatusFlags,
  args: pollStatusArgs,
  handler: (parsed) =>
    Effect.gen(function* () {
      const [{ pollStatusHandler }, { BuildersFullLive }] = yield* Effect.all([
        Effect.promise(() => import("./handler")),
        Effect.promise(() => import("../../../services/layers"))
      ], { concurrency: "unbounded" })
      yield* pollStatusHandler(parsed).pipe(Effect.provide(BuildersFullLive))
    })
})
