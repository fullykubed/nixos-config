import { Effect } from "effect"
import { defineCommand, type TypedParsed } from "../../../cli/types"

const hookFlags = [] as const
const hookArgs = [
  { name: "event", description: "Event type", required: true },
  { name: "session", description: "Session name", required: true },
  { name: "window", description: "Window name", required: true },
] as const

export type Parsed = TypedParsed<typeof hookFlags, typeof hookArgs>

export const hookCommand = defineCommand({
  name: "_hook",
  description: "Internal: handle tmux lifecycle hooks",
  flags: hookFlags,
  args: hookArgs,
  handler: (parsed) =>
    Effect.gen(function* () {
      const [{ hookHandler }, { MuxFullLive }] = yield* Effect.all([
        Effect.promise(() => import("./handler")),
        Effect.promise(() => import("../../../services/layers")),
      ], { concurrency: "unbounded" })
      yield* hookHandler(parsed).pipe(Effect.provide(MuxFullLive))
    }),
})