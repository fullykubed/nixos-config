import { Effect } from "effect"
import { defineCommand, type TypedParsed } from "../../../cli/types"

const showConfigFlags = [
  {
    kind: "boolean",
    name: "json",
    description: "Output results in JSON format",
    default: false
  }
] as const

const showConfigArgs = [] as const

export type Parsed = TypedParsed<typeof showConfigFlags, typeof showConfigArgs>

export const showConfigCommand = defineCommand({
  name: "show-config",
  description: "Show the project config for the current working directory",
  flags: showConfigFlags,
  args: showConfigArgs,
  handler: (parsed) =>
    Effect.gen(function* () {
      const [{ showConfigHandler }, { MuxFullLive }] = yield* Effect.all([
        Effect.promise(() => import("./handler")),
        Effect.promise(() => import("../../../services/layers")),
      ], { concurrency: "unbounded" })
      yield* showConfigHandler(parsed).pipe(Effect.provide(MuxFullLive))
    })
})
