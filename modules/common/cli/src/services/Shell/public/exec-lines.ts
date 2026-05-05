import { Effect } from "effect"
import { Command } from "@effect/platform"
import { ShellError } from "../errors"

/**
 * Run a command and return its stdout split into an array of lines.
 */
export const execLines = (
  cmd: string,
  args: readonly string[],
) => {
  const cmdString = `${cmd} ${args.join(" ")}`
  const command = Command.make(cmd, ...args)

  return Effect.gen(function* () {
    const lines = yield* Effect.catchAll(
      Command.lines(command),
      (error) => Effect.fail(new ShellError({
        command: cmdString,
        exitCode: -1,
        stdout: "",
        stderr: String(error)
      }))
    )

    return lines as readonly string[]
  })
}
