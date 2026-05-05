import { Effect } from "effect"
import { TmuxService } from "../../Tmux"
import type { ProjectId } from "../../Git"
import { MuxTmuxSyncError } from "../errors"
import { MUX_PROJECT_ID_OPTION } from "../types"

/**
 * Tag a tmux session with a project id by setting the `@mux_project_id`
 * user option on the given session.
 */
export const setSessionProjectId = (sessionName: string, projectId: ProjectId) =>
  Effect.gen(function* () {
    const tmux = yield* TmuxService
    yield* tmux.setSessionOption(MUX_PROJECT_ID_OPTION, projectId, sessionName).pipe(
      Effect.catchAll((cause) => Effect.fail(new MuxTmuxSyncError({
        message: `Failed to tag tmux session '${sessionName}' with project id`,
        cause,
      })))
    )
  })
