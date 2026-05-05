import { Effect } from "effect"
import { defineCommand, type TypedParsed } from "../../../cli/types"

const ensureFlags = [] as const
const ensureArgs = [
  { name: "hostname", description: "Builder hostname", required: true },
  { name: "port", description: "SSH port to check", required: true }
] as const

export type Parsed = TypedParsed<typeof ensureFlags, typeof ensureArgs>

export const ensureCommand = defineCommand({
  name: "ensure",
  description: "Ensure a builder exists and is reachable (SSH Match exec)",
  flags: ensureFlags,
  args: ensureArgs,
  handler: (parsed) =>
    Effect.gen(function* () {
      const [{ ensureHandler }, { BuildersFullLive }] = yield* Effect.all([
        Effect.promise(() => import("./handler")),
        Effect.promise(() => import("../../../services/layers"))
      ], { concurrency: "unbounded" })
      yield* ensureHandler(parsed).pipe(Effect.provide(BuildersFullLive))
    })
})
