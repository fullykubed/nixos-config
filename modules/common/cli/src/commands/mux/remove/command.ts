import { Effect } from "effect"
import { defineCommand, type TypedParsed } from "../../../cli/types"
import { BranchName } from "../../../services/Git"

const removeFlags = [
  { kind: "boolean", name: "force", short: "f", description: "Force removal even if worktree has changes", default: false },
] as const

const removeArgs = [{ name: "branch", description: "Branch name (defaults to current worktree)", required: false, brand: BranchName }] as const

export type Parsed = TypedParsed<typeof removeFlags, typeof removeArgs>

export const removeCommand = defineCommand({
  name: "remove",
  description: "Remove a worktree and close its tmux window",
  flags: removeFlags,
  args: removeArgs,
  handler: (parsed) =>
    Effect.gen(function* () {
      const [{ removeHandler }, { MuxFullLive }] = yield* Effect.all([
        Effect.promise(() => import("./handler")),
        Effect.promise(() => import("../../../services/layers")),
      ], { concurrency: "unbounded" })
      yield* removeHandler(parsed).pipe(Effect.provide(MuxFullLive))
    }),
})