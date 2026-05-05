import { Effect, Schedule } from "effect"
import { FileSystem } from "@effect/platform"
import { ShellService } from "../../Shell"
import { CrocSendError } from "../errors"
import { RELAY_ADDRESS } from "../config"

export const send = (
  filePath: string,
  opts: {
    readonly code: string
    readonly relayPass: string
    readonly timeout?: number
    readonly maxRetries?: number
  },
) => {
  const maxRetries = opts.maxRetries ?? 12
  const timeout = opts.timeout ?? 120_000

  return Effect.gen(function* () {
    const shell = yield* ShellService
    const fs = yield* FileSystem.FileSystem

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
}