import { Context, Data, Effect, Either, Layer } from "effect"
import * as Command from "@effect/platform/Command"
import { CommandExecutor } from "@effect/platform"

/**
 * Shell command execution service.
 *
 * Lowest-level service in the dependency graph — all other services (Hcloud,
 * Ssh, Tailscale) depend on it to run CLI tools.  Wraps @effect/platform's
 * Command module and provides three execution modes:
 *
 *   exec      – run a process, capture stdout/stderr/exitCode
 *   execJson  – run a process and JSON-parse its stdout
 *   execLines – run a process and split stdout into lines
 *
 * Requires CommandExecutor from the platform layer (provided once at the
 * application root via BunContext.layer).
 */

/** Raised when a shell command exits non-zero or times out. */
export class ShellError extends Data.TaggedError("ShellError")<{
  readonly command: string
  readonly exitCode: number
  readonly stdout: string
  readonly stderr: string
}> {}

/** Raised when execJson succeeds at running the command but fails to parse its stdout as JSON. */
export class JsonParseError extends Data.TaggedError("JsonParseError")<{
  readonly command: string
  readonly raw: string
  readonly error: string
}> {}

export interface ShellServiceShape {
  /**
   * Run a command, capturing its combined output.
   *
   * @param cmd       - Executable name (resolved via PATH).
   * @param args      - Argument vector.
   * @param opts.timeout - Kill the process after this many milliseconds (default 30 000).
   * @param opts.env     - Extra environment variables merged into the child's env.
   * @returns stdout, stderr, and exitCode (always 0 on success — non-zero throws ShellError).
   */
  exec(cmd: string, args: readonly string[], opts?: {
    timeout?: number
    env?: Record<string, string>
    cwd?: string
  }): Effect.Effect<{ stdout: string; stderr: string; exitCode: number }, ShellError>

  /**
   * Run a command and JSON-parse its stdout into T.
   * Fails with ShellError if the process fails, or JsonParseError if parsing fails.
   */
  execJson<T>(cmd: string, args: readonly string[]): Effect.Effect<T, ShellError | JsonParseError>

  /**
   * Run a command and return its stdout split into an array of lines.
   */
  execLines(cmd: string, args: readonly string[]): Effect.Effect<readonly string[], ShellError>
}

export class ShellService extends Context.Tag("ShellService")<
  ShellService,
  ShellServiceShape
>() {}

export const ShellLive = Layer.effect(
  ShellService,
  Effect.gen(function* () {
    const executor = yield* CommandExecutor.CommandExecutor
    const provide = <A, E>(effect: Effect.Effect<A, E, CommandExecutor.CommandExecutor>): Effect.Effect<A, E> =>
      Effect.provideService(effect, CommandExecutor.CommandExecutor, executor)

    return ShellService.of({
      exec: (cmd, args, opts) => {
        let finalCommand = Command.make(cmd, ...args)
        if (opts?.env) finalCommand = Command.env(finalCommand, opts.env)
        if (opts?.cwd) finalCommand = Command.workingDirectory(finalCommand, opts.cwd)
        const cmdString = `${cmd} ${args.join(" ")}`
        const timeoutMs = opts?.timeout ?? 30000

        return provide(
          Effect.gen(function* () {
            const result = yield* Effect.either(
              Effect.timeoutFail(Command.string(finalCommand), {
                duration: timeoutMs,
                onTimeout: () => new ShellError({
                  command: cmdString,
                  exitCode: -1,
                  stdout: "",
                  stderr: "Command timed out"
                })
              })
            )

            if (Either.isLeft(result)) {
              return yield* Effect.fail(new ShellError({
                command: cmdString,
                exitCode: -1,
                stdout: "",
                stderr: String(result.left)
              }))
            }

            return { stdout: result.right, stderr: "", exitCode: 0 }
          })
        )
      },

      execJson: <T>(cmd: string, args: readonly string[]) => {
        const cmdString = `${cmd} ${args.join(" ")}`
        const command = Command.make(cmd, ...args)

        return provide(
          Effect.gen(function* () {
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
        )
      },

      execLines: (cmd, args) => {
        const cmdString = `${cmd} ${args.join(" ")}`
        const command = Command.make(cmd, ...args)

        return provide(
          Effect.gen(function* () {
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
        )
      }
    })
  })
)
