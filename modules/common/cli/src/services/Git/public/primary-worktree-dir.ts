import { Effect } from "effect"
import type {} from "../errors"
import type { GitCommonPath } from "../types"
import { worktreeList } from "./worktree-list"

export const primaryWorktreeDir = (cwd: GitCommonPath) =>
  Effect.gen(function* () {
    const worktrees = yield* worktreeList(cwd)
    const primary = worktrees.find(wt => wt.isPrimary)
    return primary?.path ?? null
  })
