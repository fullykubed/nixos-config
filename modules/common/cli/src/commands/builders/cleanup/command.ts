import { Effect } from "effect"
import { defineCommand, type TypedParsed } from "../../../cli/types"

const cleanupFlags = [
  {
    kind: "boolean",
    name: "yes",
    short: "y",
    description: "Skip confirmation prompt",
    default: false
  },
  {
    kind: "boolean",
    name: "json",
    description: "Output results as JSON",
    default: false
  }
] as const

const cleanupArgs = [] as const

export type Parsed = TypedParsed<typeof cleanupFlags, typeof cleanupArgs>

export const cleanupCommand = defineCommand({
  name: "cleanup",
  description: "Delete old builder snapshots, keeping only the latest",
  flags: cleanupFlags,
  args: cleanupArgs,
  handler: (parsed) =>
    Effect.gen(function* () {
      const [{ cleanupHandler }, { HcloudFullLive }] = yield* Effect.all([
        Effect.promise(() => import("./handler")),
        Effect.promise(() => import("../../../services/layers"))
      ], { concurrency: "unbounded" })
      yield* cleanupHandler(parsed).pipe(Effect.provide(HcloudFullLive))
    })
})
