import { Effect } from "effect"
import { defineCommand, type TypedParsed } from "../../../cli/types"
import { BranchName } from "../../../services/Git"

const createFlags = [] as const
const createArgs = [{ name: "branch", description: "Git branch name for the worktree", required: true, brand: BranchName }] as const

export type Parsed = TypedParsed<typeof createFlags, typeof createArgs>

export const createCommand = defineCommand({
  name: "create",
  description: "Create a new worktree with tmux window",
  flags: createFlags,
  args: createArgs,
  handler: (parsed) =>
    Effect.gen(function* () {
      const [{ createHandler }, { MuxFullLive }] = yield* Effect.all([
        Effect.promise(() => import("./handler")),
        Effect.promise(() => import("../../../services/layers")),
      ], { concurrency: "unbounded" })
      yield* createHandler(parsed).pipe(Effect.provide(MuxFullLive))
    }),
})