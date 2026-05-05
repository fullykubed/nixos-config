import { Effect } from "effect"
import { Command } from "@effect/platform"
import { ShellError, JsonParseError } from "../errors"

/**
 * Run a command and JSON-parse its stdout into T.
 * Fails with ShellError if the process fails, or JsonParseError if parsing fails.
 */
export const execJson = <T>(
  cmd: string,
  args: readonly string[],
) => {
  const cmdString = `${cmd} ${args.join(" ")}`
  const command = Command.make(cmd, ...args)

  return Effect.gen(function* () {
    const stdout = yield* Effect.catchAll(
      Command.string(command),
      (error) => Effect.fail(new ShellError({
        command: cmdString,
        exitCode: -1,
        stdout: "",
        stderr: String(error)
      }))
    )

    return yield* Effect.try({
      try: () => JSON.parse(stdout) as T,
      catch: (error) => new JsonParseError({
        command: cmdString,
        raw: stdout,
        error: error instanceof Error ? error.message : String(error)
      })
    })
  })
}
