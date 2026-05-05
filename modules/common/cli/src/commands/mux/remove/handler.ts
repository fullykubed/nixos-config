import { Effect, Option } from "effect"
import type { Parsed } from "./command"
import { GitService, AbsolutePath } from "../../../services/Git"
import { MuxService } from "../../../services/Mux"

export const removeHandler = (parsed: Parsed) =>
  Effect.gen(function* () {
    const git = yield* GitService
    const mux = yield* MuxService

    // 1. Resolve target worktree from DB
    const entry = yield* resolveWorktree(parsed, mux, git)

    // 2. Check if worktree has uncommitted changes
    if (entry.path) {
      const isDirty = yield* git.isDirty(entry.path)

      if (isDirty && !parsed.flags.force) {
        yield* Effect.fail(new Error(`Worktree has uncommitted changes. Use --force to remove anyway: ${entry.path}`))
      }
    }

    // 5. Remove worktree (git + tmux + DB handled by service)
    const { windowClosed } = yield* mux.removeWorktree(entry.id)

    // 6. Print success message
    yield* Effect.log(`Removed worktree '${entry.branch}'${windowClosed ? " and closed tmux window" : ""}`)
  })

/** Resolve the target worktree entry from whichever flag is provided, or infer from cwd. */
const resolveWorktree = (
  parsed: Parsed,
  mux: Effect.Effect.Success<typeof MuxService>,
  git: Effect.Effect.Success<typeof GitService>,
) =>
  Effect.gen(function* () {
    if (parsed.flags.id !== undefined) {
      return yield* mux.getWorktreeById(parsed.flags.id).pipe(
        Effect.flatMap(Option.match({
          onNone: () => Effect.fail(new Error(`No worktree found with id '${parsed.flags.id}'`)),
          onSome: Effect.succeed,
        })),
      )
    }

    if (parsed.flags.path !== undefined) {
      return yield* mux.getWorktreeFromPath(parsed.flags.path).pipe(
        Effect.flatMap(Option.match({
          onNone: () => Effect.fail(new Error(`No worktree found at path '${parsed.flags.path}'`)),
          onSome: Effect.succeed,
        })),
      )
    }

    const cwd = AbsolutePath(process.cwd())

    if (parsed.flags.branch !== undefined) {
      const projectPath = yield* git.projectDir(yield* git.repoRoot(cwd))
      return yield* mux.getWorktreeFromBranch(projectPath, parsed.flags.branch).pipe(
        Effect.flatMap(Option.match({
          onNone: () => Effect.fail(new Error(`Worktree for branch '${parsed.flags.branch}' not found`)),
          onSome: Effect.succeed,
        })),
      )
    }

    // No flag — infer from cwd
    const isWt = yield* git.isWorktree(cwd)
    if (Option.isNone(isWt)) {
      return yield* Effect.fail(new Error("Specify --branch, --id, or --path, or run from inside a worktree"))
    }

    return yield* mux.getWorktreeFromPath(cwd).pipe(
      Effect.flatMap(Option.match({
        onNone: () => Effect.fail(new Error("Current directory is not a tracked worktree. Specify --branch, --id, or --path")),
        onSome: Effect.succeed,
      })),
    )
  })
