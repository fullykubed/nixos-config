import { Effect, Stream } from "effect"
import { Command } from "@effect/platform"
import { ShellError } from "../errors"

/**
 * Run a command, capturing stdout, stderr, and exit code.
 * Fails with ShellError on non-zero exit or spawn failure.
 */
export const exec = (
  cmd: string,
  args: readonly string[],
  opts?: { timeout?: number; env?: Record<string, string>; cwd?: string; stdin?: string },
) => {
  let finalCommand = Command.make(cmd, ...args)
  if (opts?.env) finalCommand = Command.env(finalCommand, opts.env)
  if (opts?.cwd) finalCommand = Command.workingDirectory(finalCommand, opts.cwd)
  if (opts?.stdin != null) finalCommand = Command.feed(finalCommand, opts.stdin)
  const cmdString = `${cmd} ${args.join(" ")}`
  const timeoutMs = opts?.timeout ?? 30000

  const collectStream = (stream: Stream.Stream<Uint8Array, unknown>) =>
    stream.pipe(
      Stream.catchAll(() => Stream.empty),
      Stream.decodeText(),
      Stream.runFold("", (acc, chunk) => acc + chunk),
    )

  return Effect.gen(function* () {
    const { stdout, stderr, exitCode } = yield* Effect.scoped(
      Effect.gen(function* () {
        const process = yield* Command.start(finalCommand)
        const [stdout, stderr, code] = yield* Effect.all([
          collectStream(process.stdout),
          collectStream(process.stderr),
          process.exitCode,
        ])
        return { stdout, stderr, exitCode: code as number }
      }),
    ).pipe(
      // Catch PlatformError (SystemError/BadArgument) from Command.start before timeout
      Effect.catchAll((e) =>
        Effect.fail(new ShellError({ command: cmdString, exitCode: -1, stdout: "", stderr: String(e) })),
      ),
      Effect.timeoutFail({
        duration: timeoutMs,
        onTimeout: () =>
          new ShellError({ command: cmdString, exitCode: -1, stdout: "", stderr: "Command timed out" }),
      }),
    )

    if (exitCode !== 0) {
      return yield* Effect.fail(
        new ShellError({ command: cmdString, exitCode, stdout, stderr }),
      )
    }

    return { stdout, stderr, exitCode }
  })
}
