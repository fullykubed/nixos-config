import { Effect } from "effect"
import { TmuxService } from "../../Tmux"
import type { ProjectId } from "../../Git"
import { MuxTmuxSyncError } from "../errors"
import { findSessionByProjectId } from "./find-session-by-project-id"
import { setSessionProjectId } from "./set-session-project-id"

/**
 * Ensure the correct tmux session exists for a project.
 *
 * If a session with the given name already exists, returns it. Otherwise
 * searches all sessions for one tagged with the project's id and renames
 * it. Failing that, creates a new session. Tags the session with
 * `@mux_project_id` before returning.
 */
export const createSession = (sessionName: string, projectId: ProjectId) =>
  Effect.gen(function* () {
    const tmux = yield* TmuxService

    // Check if session with correct name already exists
    const exists = yield* tmux.sessionExists(sessionName)
    if (!exists) {
      // Search for a session already tagged with this project's ID
      const existing = yield* findSessionByProjectId(projectId)
      if (existing) {
        yield* tmux.renameSession(existing, sessionName).pipe(
          Effect.catchAll((cause) => Effect.fail(new MuxTmuxSyncError({
            message: `Failed to rename tmux session '${existing}' to '${sessionName}'`,
            cause,
          })))
        )
      } else {
        yield* tmux.ensureSession(sessionName).pipe(
          Effect.catchAll((cause) => Effect.fail(new MuxTmuxSyncError({
            message: `Failed to create tmux session '${sessionName}'`,
            cause,
          })))
        )
      }
    }

    yield* setSessionProjectId(sessionName, projectId)

    return sessionName
  })
