import { Effect } from "effect"
import { ShellService } from "../../Shell"
import type { ProjectId } from "../../Git"
import { MUX_PROJECT_ID_OPTION } from "../types"

/**
 * Search all tmux sessions for one tagged with the given project id.
 *
 * Runs `tmux list-sessions -F "#{session_name}:#{@mux_project_id}"` and
 * parses each line as `<name>:<id>`. Returns the session name whose
 * `@mux_project_id` matches, or undefined if none found.
 */
export const findSessionByProjectId = (projectId: ProjectId) =>
  Effect.gen(function* () {
    const shell = yield* ShellService
    return yield* shell.exec("tmux", ["list-sessions", "-F", `#{session_name}:#{${MUX_PROJECT_ID_OPTION}}`]).pipe(
      Effect.map(({ stdout }) => parseSessionList(stdout, projectId)),
      Effect.catchAll(() => Effect.succeed(undefined)),
    )
  })

/** Parse tmux list-sessions output and find the session tagged with projectId. */
export const parseSessionList = (stdout: string, projectId: string): string | undefined => {
  for (const line of stdout.trim().split("\n")) {
    const sep = line.lastIndexOf(":")
    if (sep === -1) continue
    const name = line.slice(0, sep)
    const id = line.slice(sep + 1)
    if (id === projectId) return name
  }
  return undefined
}
