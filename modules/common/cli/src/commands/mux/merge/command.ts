import { Effect } from "effect"
import { defineCommand, type TypedParsed } from "../../../cli/types"
import { BranchName } from "../../../services/Git"

const mergeFlags = [
  { kind: "string", name: "into", description: "Target branch (defaults to primary_branch from project.json)", required: false, brand: BranchName },
] as const

const mergeArgs = [] as const

export type Parsed = TypedParsed<typeof mergeFlags, typeof mergeArgs>

export const mergeCommand = defineCommand({
  name: "merge",
  description: "Merge current worktree into primary branch and clean up",
  flags: mergeFlags,
  args: mergeArgs,
  handler: (parsed) =>
    Effect.gen(function* () {
      const [{ mergeHandler }, { MuxFullLive }] = yield* Effect.all([
        Effect.promise(() => import("./handler")),
        Effect.promise(() => import("../../../services/layers")),
      ], { concurrency: "unbounded" })
      yield* mergeHandler(parsed).pipe(Effect.provide(MuxFullLive))
    }) as Effect.Effect<void>,
})