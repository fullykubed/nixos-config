import { Effect, Option } from "effect"
import { FileSystem, Path } from "@effect/platform"
import type { AbsolutePath } from "../types"
import { WorktreePath } from "../types"

/**
 * Checks if a path is a git worktree (not the main repo).
 * In a worktree, `.git` is a **file** pointing to the main repo's worktree dir.
 * In the main repo, `.git` is a **directory**.
 */
export const isWorktree = (path: AbsolutePath) =>
  Effect.gen(function* () {
    const fs = yield* FileSystem.FileSystem
    const p = yield* Path.Path
    const gitPath = p.join(path, ".git")
    const stat = yield* fs.stat(gitPath).pipe(Effect.catchAll(() => Effect.succeed(null)))
    if (stat === null) return Option.none()
    // Worktrees have a .git file; main repos have a .git directory
    return stat.type === "File" ? Option.some(WorktreePath(path)) : Option.none()
  })