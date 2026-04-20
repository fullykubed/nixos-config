import { Context, Data, Effect, Layer, Schedule, Scope } from "effect"
import { FileSystem } from "@effect/platform"
import { ShellService } from "./Shell"

const RELAY_ADDRESS = "headscale.panfactumcf.com:19009"
const RELAY_PASS_PATH = "/run/agenix/croc-relay-password"

/** The croc relay is not reachable (TCP connectivity check failed). */
export class CrocRelayUnreachableError extends Data.TaggedError("CrocRelayUnreachableError")<{
  readonly relayAddress: string
}> {}

/** Failed to read the croc relay password from the agenix secret. */
export class CrocRelayPassError extends Data.TaggedError("CrocRelayPassError")<{
  readonly path: string
  readonly message: string
}> {}

/** Failed to generate a croc transfer code. */
export class CrocCodeError extends Data.TaggedError("CrocCodeError")<{
  readonly message: string
}> {}

/** croc send failed after all retry attempts. */
export class CrocSendError extends Data.TaggedError("CrocSendError")<{
  readonly target: string
  readonly attempts: number
  readonly message: string
}> {}

export interface CrocServiceShape {
  /** The relay address (host:port) used for all transfers. */
  readonly relayAddress: string

  /**
   * Check that the croc relay is reachable via TCP.
   * Fails with CrocRelayUnreachableError if the relay cannot be reached.
   */
  checkRelay(): Effect.Effect<void, CrocRelayUnreachableError>

  /**
   * Generate a random croc transfer code (32 hex chars).
   */
  generateCode(): Effect.Effect<string, CrocCodeError>

  /**
   * Read the croc relay password from the agenix secret on disk.
   */
  readRelayPass(): Effect.Effect<string, CrocRelayPassError>

  /**
   * Send a file via croc with automatic retries.
   *
   * @param filePath   Absolute path to the file to send.
   * @param opts.code  Croc secret code for the transfer.
   * @param opts.relayPass  Relay password.
   * @param opts.timeout  Per-attempt timeout in ms (default: 120_000).
   * @param opts.maxRetries  Maximum retry attempts (default: 12, total attempts = maxRetries).
   */
  send(filePath: string, opts: {
    readonly code: string
    readonly relayPass: string
    readonly timeout?: number
    readonly maxRetries?: number
  }): Effect.Effect<void, CrocSendError, Scope.Scope>
}

export class CrocService extends Context.Tag("CrocService")<
  CrocService,
  CrocServiceShape
>() {}

const makeCrocService = (
  shell: ShellService["Type"],
  fs: FileSystem.FileSystem,
): CrocServiceShape => ({
  relayAddress: RELAY_ADDRESS,

  checkRelay: () => {
    const [host, port] = RELAY_ADDRESS.split(":")
    return shell.exec("nc", ["-z", "-w", "2", host!, port!]).pipe(
      Effect.asVoid,
      Effect.catchAll(() => Effect.fail(new CrocRelayUnreachableError({ relayAddress: RELAY_ADDRESS })))
    )
  },

  generateCode: () =>
    shell.exec("openssl", ["rand", "-hex", "16"]).pipe(
      Effect.map(result => result.stdout.trim()),
      Effect.catchAll(() => Effect.fail(new CrocCodeError({ message: "Failed to generate croc code via openssl" })))
    ),

  readRelayPass: () =>
    fs.readFileString(RELAY_PASS_PATH).pipe(
      Effect.map(text => text.trim()),
      Effect.catchAll(() => Effect.fail(new CrocRelayPassError({
        path: RELAY_PASS_PATH,
        message: `Failed to read croc relay password from ${RELAY_PASS_PATH}`
      })))
    ),

  send: (filePath, opts) => {
    const maxRetries = opts.maxRetries ?? 12
    const timeout = opts.timeout ?? 120_000

    return Effect.gen(function* () {
      const cwd = yield* fs.makeTempDirectoryScoped({ prefix: "croc-send-" }).pipe(
        Effect.catchAll(() => Effect.fail(new CrocSendError({
          target: filePath,
          attempts: 0,
          message: "Failed to create temporary directory for croc send",
        })))
      )

      yield* shell.exec(
        "croc",
        ["--yes", "--quiet", "--relay", RELAY_ADDRESS, "--pass", opts.relayPass, "send", filePath],
        {
          env: { CROC_SECRET: opts.code },
          cwd,
          timeout,
        }
      ).pipe(
        Effect.retry(
          Schedule.spaced("5 seconds").pipe(
            Schedule.intersect(Schedule.recurs(maxRetries - 1)),
            Schedule.tapInput(() => Effect.logWarning("croc send failed, retrying in 5s..."))
          )
        ),
        Effect.asVoid,
        Effect.catchAll(() => Effect.fail(new CrocSendError({
          target: filePath,
          attempts: maxRetries,
          message: `croc send failed after ${maxRetries} attempts`,
        })))
      )
    })
  },
})

export const CrocLive = Layer.effect(
  CrocService,
  Effect.gen(function* () {
    const shell = yield* ShellService
    const fileSystem = yield* FileSystem.FileSystem
    return makeCrocService(shell, fileSystem)
  })
)
