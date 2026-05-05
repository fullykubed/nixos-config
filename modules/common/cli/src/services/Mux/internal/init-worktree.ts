import { Effect } from "effect"
import { FileSystem, Path } from "@effect/platform"
import { ShellService } from "../../Shell"
import { GitService, WorktreePath } from "../../Git"
import { MuxInitWorktreeError } from "../errors"

/**
 * Initialize a new worktree: read config, glob-copy files from the primary worktree, and run post_create hooks.
 */
export const initWorktree = (
  worktreePath: WorktreePath,
) =>
  Effect.gen(function* () {
    const shell = yield* ShellService
    const git = yield* GitService
    const fs = yield* FileSystem.FileSystem
    const path = yield* Path.Path

    const projectRoot = yield* git.projectDir(worktreePath)
    const commonDir = yield* git.commonDir(worktreePath)
    const primaryDir = yield* git.primaryWorktreeDir(commonDir)
    const config = yield* git.getProjectConfig(projectRoot)

    if (primaryDir !== null) {
      // Expand copy and link globs in parallel
      const [copyMatches, linkMatches] = yield* Effect.all([
        Effect.forEach(config.worktree.files.copy, (pattern) => expandGlob(primaryDir, pattern), { concurrency: "unbounded" }),
        Effect.forEach(config.worktree.files.link, (pattern) => expandGlob(primaryDir, pattern), { concurrency: "unbounded" }),
      ], { concurrency: "unbounded" })

      const copyEntries = removeNestedPaths([...new Set(copyMatches.flat())])
      const linkEntries = removeNestedPaths([...new Set(linkMatches.flat())])

      // Fail if any path would be both copied and linked
      const conflicts = findConflicts(copyEntries, linkEntries)
      if (conflicts.length > 0) {
        yield* Effect.fail(new MuxInitWorktreeError({
          message: `Paths appear in both copy and link: ${conflicts.join(", ")}`,
          paths: conflicts,
        }))
      }

      // Copy first, then link
      yield* Effect.forEach(copyEntries, (relativePath) =>
        Effect.gen(function* () {
          const sourcePath = path.join(primaryDir, relativePath)
          const destinationPath = path.join(worktreePath, relativePath)
          yield* fs.makeDirectory(path.dirname(destinationPath), { recursive: true }).pipe(
            Effect.catchAll(() => Effect.void) // Handle platform errors
          )
          yield* fs.copy(sourcePath, destinationPath).pipe(
            Effect.catchAll((e) => Effect.fail(new MuxInitWorktreeError({
              message: `Failed to copy ${relativePath}: ${String(e)}`,
              paths: [relativePath]
            })))
          )
        }),
        { concurrency: "unbounded", discard: true }
      )

      yield* Effect.forEach(linkEntries, (relativePath) =>
        Effect.gen(function* () {
          const sourcePath = path.resolve(path.join(primaryDir, relativePath))
          const destinationPath = path.join(worktreePath, relativePath)
          yield* fs.makeDirectory(path.dirname(destinationPath), { recursive: true }).pipe(
            Effect.catchAll(() => Effect.void) // Handle platform errors
          )
          yield* fs.symlink(sourcePath, destinationPath).pipe(
            Effect.catchAll((e) => Effect.fail(new MuxInitWorktreeError({
              message: `Failed to link ${relativePath}: ${String(e)}`,
              paths: [relativePath]
            })))
          )
        }),
        { concurrency: "unbounded", discard: true }
      )
    }

    yield* Effect.forEach(config.worktree.post_create, (hookCmd) =>
      shell.exec("sh", ["-c", hookCmd], { cwd: worktreePath }).pipe(
        Effect.catchAll((e) => Effect.fail(new MuxInitWorktreeError({
          message: `Hook "${hookCmd}" failed: ${String(e)}`,
          paths: []
        })))
      ),
      { discard: true }
    )
  })

/** Remove paths that are nested inside another path in the list. */
export const removeNestedPaths = (paths: readonly string[]): readonly string[] => {
  const sorted = [...paths].sort()
  const result: string[] = []
  let lastKept = ""
  for (const entry of sorted) {
    if (lastKept && entry.startsWith(lastKept + "/")) continue
    result.push(entry)
    lastKept = entry
  }
  return result
}

/**
 * Find paths that conflict between copy and link sets.
 * A conflict is an exact match or a parent/child relationship.
 */
export const findConflicts = (
  copyEntries: readonly string[],
  linkEntries: readonly string[],
): readonly string[] => {
  const conflicts: string[] = []
  for (const c of copyEntries) {
    for (const l of linkEntries) {
      if (c === l || c.startsWith(l + "/") || l.startsWith(c + "/")) {
        conflicts.push(c === l ? c : c.length < l.length ? c : l)
      }
    }
  }
  return [...new Set(conflicts)]
}

/** Expand a glob pattern relative to a directory, returning relative paths (files and directories). */
const expandGlob = (cwd: string, pattern: string) =>
  Effect.tryPromise({
    try: async () => {
      const glob = new Bun.Glob(pattern)
      const results: string[] = []
      for await (const match of glob.scan({ cwd, dot: true, onlyFiles: false })) {
        results.push(match)
      }
      return results
    },
    catch: () => [] as readonly string[],
  }).pipe(Effect.catchAll(() => Effect.succeed([] as readonly string[])))
