import { Effect, Exit, Schedule } from "effect"
import { FileSystem } from "@effect/platform"
import { HcloudService } from "../../Hcloud"
import { TailscaleService } from "../../Tailscale"
import { CrocService } from "../../Croc"
import { LockService } from "../../Lock"
import { BuilderCreateError } from "../errors"
import { builderType, serverTypeFor, SECRET_PATHS } from "../internal/helpers"
import { ensureCcacheVolume } from "../internal/ensure-ccache-volume"
import { startBuilder } from "../internal/start-builder"
import { sendSecrets } from "../internal/send-secrets"
import { isReady } from "./is-ready"
import { ensureReadyOrDestroy } from "../internal/ensure-ready-or-destroy"

/**
 * Create a new builder end-to-end: validate preconditions, provision server,
 * deliver secrets via croc, and wait for Tailscale registration.
 * Auto-deletes the server on initialization failure.
 */
export const create = (name: string) =>
  Effect.gen(function* () {
    const hcloud = yield* HcloudService
    const tailscale = yield* TailscaleService
    const fs = yield* FileSystem.FileSystem
    const croc = yield* CrocService
    const lock = yield* LockService

    // If server already exists, check readiness or recycle stale builders
    const alreadyExists = yield* hcloud.serverExists(name).pipe(
      Effect.catchAll(() => Effect.succeed(false))
    )
    if (alreadyExists) {
      const readyOrDestroyed = yield* ensureReadyOrDestroy(name).pipe(
        Effect.catchAll((err) => Effect.fail(new BuilderCreateError({ name, message: "Failed to destroy stale builder", cause: err })))
      )
      if (readyOrDestroyed) {
        yield* Effect.log(`${name} already exists and is ready`)
        return
      }
    }

    yield* lock.withLock(`builder-create-${name}`, (lockInfo) => Effect.gen(function* () {
      // Another process held the lock — it may have already created the builder
      if (lockInfo.waited) {
        const existsNow = yield* hcloud.serverExists(name).pipe(
          Effect.catchAll(() => Effect.succeed(false))
        )
        if (existsNow) {
          const readyNow = yield* ensureReadyOrDestroy(name).pipe(
            Effect.catchAll((err) => Effect.fail(new BuilderCreateError({ name, message: "Failed to destroy stale builder", cause: err })))
          )
          if (readyNow) {
            yield* Effect.log(`${name} was created by another process while waiting for lock`)
            return
          }
        }
      }

      const btype = builderType(name)
      const serverType = serverTypeFor(name)

      yield* Effect.log(`Creating ${name} (${btype}, ${serverType})...`)

      // Resolve latest builder snapshot
      const images = yield* hcloud.listImages("snapshot", { type: "builder" }).pipe(
        Effect.catchAll((err) => Effect.fail(new BuilderCreateError({ name, message: "Failed to list builder snapshots", cause: err })))
      )
      const sortedImages = images
        .filter(img => img.type === "snapshot")
        .sort((a, b) => new Date(a.created).getTime() - new Date(b.created).getTime())

      const latestSnapshot = sortedImages[sortedImages.length - 1]
      if (!latestSnapshot) {
        return yield* Effect.fail(new BuilderCreateError({ name, message: "No snapshot found with label type=builder" }))
      }

      // Validate secret files exist
      const secretPaths = Object.values(SECRET_PATHS)
      for (const path of secretPaths) {
        const pathExists = yield* fs.exists(path).pipe(
          Effect.catchAll(() => Effect.succeed(false))
        )
        if (!pathExists) {
          return yield* Effect.fail(new BuilderCreateError({ name, message: `Secret file not found: ${path}` }))
        }
      }

      // Check croc relay reachability
      yield* croc.checkRelay().pipe(
        Effect.catchAll((err) => Effect.fail(new BuilderCreateError({
          name, message: `Croc relay not reachable at ${croc.relayAddress}`, cause: err
        })))
      )
      yield* Effect.log("Croc relay is reachable")

      // Mint headscale pre-auth key
      yield* Effect.log("Minting headscale pre-auth key...")
      const authKey = yield* tailscale.mintPreAuthKey().pipe(
        Effect.catchAll((err) => Effect.fail(new BuilderCreateError({
          name, message: "Failed to mint pre-auth key", cause: err
        })))
      )

      // Generate croc code and read relay password
      const crocCode = yield* croc.generateCode().pipe(
        Effect.catchAll((err) => Effect.fail(new BuilderCreateError({ name, message: "Failed to generate croc code", cause: err })))
      )
      const crocRelayPass = yield* croc.readRelayPass().pipe(
        Effect.catchAll((err) => Effect.fail(new BuilderCreateError({ name, message: "Failed to read croc relay password", cause: err })))
      )

      const { volumeId, created: volumeCreated } = yield* ensureCcacheVolume(hcloud, name).pipe(
        Effect.catchAll((err) => Effect.fail(new BuilderCreateError({ name, message: "Failed to ensure ccache volume", cause: err })))
      )

      // Create server, send secrets, and wait for Tailscale.
      // If anything fails after the server is created, auto-delete it.
      yield* Effect.gen(function* () {
        yield* startBuilder(hcloud, {
          name,
          builderType: btype,
          serverType,
          imageId: latestSnapshot.id,
          volumeId,
          volumeCreated,
          crocCode,
          crocRelayPass,
        })

        yield* sendSecrets(fs, croc, {
          name,
          authKey,
          builderType: btype,
          crocCode,
          crocRelayPass,
        })

        // Wait for builder to become reachable over Tailscale
        yield* Effect.log(`Waiting for ${name} to become ready...`)

        yield* isReady(name).pipe(
          Effect.flatMap((ready) => ready ? Effect.void : Effect.fail("not ready" as const)),
          Effect.retry(Schedule.spaced("5 seconds").pipe(Schedule.upTo("180 seconds"))),
          Effect.catchAll(() =>
            Effect.fail(new BuilderCreateError({ name, message: `${name} did not become reachable within 180s` }))
          ),
        )

        yield* Effect.log(`${name} is ready`)
      }).pipe(
        Effect.catchAll((err) =>
          err instanceof BuilderCreateError
            ? Effect.fail(err)
            : Effect.fail(new BuilderCreateError({ name, message: "Post-creation failed", cause: err }))
        ),
        Effect.onExit((exit) =>
          Exit.isSuccess(exit)
            ? Effect.void
            : Effect.uninterruptible(
                Effect.logError(`Initialization failed, deleting ${name}...`).pipe(
                  Effect.andThen(
                    hcloud.deleteServer(name).pipe(
                      Effect.tap(() => Effect.log(`Deleted ${name}`)),
                      Effect.catchAll(() => Effect.logError(`Failed to delete ${name} — manual cleanup required`))
                    )
                  )
                )
              )
        )
      )
    }))
  })
