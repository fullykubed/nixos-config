import { Effect } from "effect"
import { defineCommand, type TypedParsed } from "../../../cli/types"
import { BranchName } from "../../../services/Git"
import { WorktreeId } from "../../../services/Mux"

const removeFlags = [
  { kind: "boolean", name: "force", short: "f", description: "Force removal even if worktree has changes", default: false },
  { kind: "string", name: "branch", short: "b", description: "Branch name of the worktree to remove", required: false, brand: BranchName },
  { kind: "string", name: "id", description: "Database ID of the worktree to remove", required: false, brand: WorktreeId },
  { kind: "path", name: "path", short: "p", description: "Filesystem path of the worktree to remove", required: false },
] as const

const removeArgs = [] as const

export type Parsed = TypedParsed<typeof removeFlags, typeof removeArgs>

export const removeCommand = defineCommand({
  name: "remove",
  description: "Remove a worktree and close its tmux window",
  flags: removeFlags,
  args: removeArgs,
  mutuallyExclusive: [["branch", "id", "path"]],
  handler: (parsed) =>
    Effect.gen(function* () {
      const [{ removeHandler }, { MuxFullLive }] = yield* Effect.all([
        Effect.promise(() => import("./handler")),
        Effect.promise(() => import("../../../services/layers")),
      ], { concurrency: "unbounded" })
      yield* removeHandler(parsed).pipe(Effect.provide(MuxFullLive))
    }),
})
