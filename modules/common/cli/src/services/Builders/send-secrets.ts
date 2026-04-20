import { Effect } from "effect"
import type { FileSystem } from "@effect/platform"
import type { CrocService } from "../Croc"
import { createInstallScript } from "./install-script"

/**
 * Build the install script (reads secrets from disk),
 * then send it to the builder via croc.
 * Uses a scoped temp file that auto-deletes when done.
 * Retries up to 12 times with 5s spacing.
 */
export const sendSecrets = (fs: FileSystem.FileSystem, croc: CrocService["Type"], opts: {
  name: string
  authKey: string
  builderType: "regular" | "big"
  crocCode: string
  crocRelayPass: string
}) =>
  Effect.gen(function* () {
    const installScript = yield* createInstallScript(fs, {
      name: opts.name,
      authKey: opts.authKey,
      builderType: opts.builderType,
    })

    yield* Effect.log(`Sending secrets to ${opts.name} via croc (waiting for builder to connect)...`)

    yield* Effect.scoped(
      Effect.gen(function* () {
        const tmpFile = yield* fs.makeTempFileScoped({ directory: "/tmp", prefix: `install-secrets-${opts.name}-` })
        yield* fs.writeFileString(tmpFile, installScript)

        yield* croc.send(tmpFile, {
          code: opts.crocCode,
          relayPass: opts.crocRelayPass,
        })
      })
    )

    yield* Effect.log(`Secrets delivered to ${opts.name} via croc`)
  })
