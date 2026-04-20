import { Context, Data, Effect, Either, Exit, Layer, Schedule } from "effect"
import { FileSystem } from "@effect/platform"
import { HcloudService, type HcloudTokenError, type HcloudListServersError, type Server } from "../Hcloud"
import { TailscaleService } from "../Tailscale"
import { SshService } from "../Ssh"
import { CrocService } from "../Croc"
import { LockService, type LockAcquireError, type LockServiceShape } from "../Lock"
import { BUILDER_CONFIG } from "./config"
import { normalizeName, isBuilderName, builderType, serverTypeFor, SECRET_PATHS } from "./helpers"
import { ensureCcacheVolume } from "./ensure-ccache-volume"
import { startBuilder } from "./start-builder"
import { sendSecrets } from "./send-secrets"
import { REMOTE_STATS_CMD } from "./stats-script"
import { parseStats } from "./parse-stats"
import { calculateUptimeHours } from "./calculate-uptime"

// ── Types ────────────────────────────────────────────────────────────

export type { Server }

/** Runtime stats collected from a builder via SSH. */
export interface BuilderStats {
  name: string
  reachable: boolean
  builds: number
  cpuPercent: number
  memUsedKb: number
  memTotalKb: number
  diskReadSectors: number
  diskWriteSectors: number
  diskTotalKb: number
  diskUsedKb: number
  diskPercent: number
  sshSessions: number
  tailscaleStatus: string
  queuePending: number
  queueDone: number
  idleCount: number
  ccacheHits: number
  ccacheMisses: number
  ccacheSizeKb: number
  ccacheMount: boolean
  ccacheSync: boolean
  serveCount: number
  uptimeHours: number
  error?: string
}

// ── Errors ───────────────────────────────────────────────────────────

/** The raw input did not resolve to a valid builder name. */
export class InvalidBuilderNameError extends Data.TaggedError("InvalidBuilderNameError")<{
  readonly input: string
}> {}

/** No builder with this name exists in Hetzner Cloud. */
export class BuilderNotFoundError extends Data.TaggedError("BuilderNotFoundError")<{
  readonly name: string
}> {}

/** The builder's Tailscale IP could not be resolved. */
export class BuilderUnreachableError extends Data.TaggedError("BuilderUnreachableError")<{
  readonly name: string
  readonly reason: string
  readonly cause?: unknown
}> {}

/** A builder could not be fully destroyed. */
export class BuilderDestroyError extends Data.TaggedError("BuilderDestroyError")<{
  readonly name: string
  readonly message: string
  readonly cause?: unknown
}> {}

/** Builder creation failed at some stage. */
export class BuilderCreateError extends Data.TaggedError("BuilderCreateError")<{
  readonly name: string
  readonly message: string
  readonly cause?: unknown
}> {}

// ── Service interface ────────────────────────────────────────────────

export interface BuildersServiceShape {
  /**
   * Normalize and validate a raw builder name input.
   * "1" → "builder-1", "big-2" → "big-builder-2", etc.
   */
  resolve(rawName: string): Effect.Effect<string, InvalidBuilderNameError>

  /**
   * List all builder servers, sorted by name.
   * Returns the full Hcloud Server objects for maximum flexibility.
   */
  list(): Effect.Effect<Server[], HcloudTokenError | HcloudListServersError>

  /**
   * Get a single builder by its (already-normalized) name.
   */
  get(name: string): Effect.Effect<Server, BuilderNotFoundError>

  /**
   * Check whether a builder exists in Hetzner Cloud.
   */
  exists(name: string): Effect.Effect<boolean>

  /**
   * Resolve a builder's Tailscale IPv4 address.
   */
  resolveIP(name: string): Effect.Effect<string, BuilderUnreachableError>

  /**
   * Check whether a builder is reachable over Tailscale (SSH port 22).
   * Fails with BuilderNotFoundError if the server doesn't exist in Hetzner Cloud.
   */
  isReady(name: string): Effect.Effect<boolean, BuilderNotFoundError>

  /**
   * Get the age of a builder in hours, based on its Hetzner creation time.
   */
  getAge(name: string): Effect.Effect<number, BuilderNotFoundError>

  /**
   * Destroy a builder: detach ccache volume, delete server, remove headscale node.
   * The operation is uninterruptible to avoid partial teardown.
   */
  destroy(name: string): Effect.Effect<void, BuilderDestroyError>

  /**
   * Create a new builder end-to-end: validate preconditions, provision server,
   * deliver secrets via croc, and wait for Tailscale registration.
   * Auto-deletes the server on initialization failure.
   */
  create(name: string): Effect.Effect<void, BuilderCreateError | LockAcquireError>

  /**
   * Fetch runtime stats from a builder via SSH.
   * Returns null if the builder is unreachable or the stats command fails.
   */
  getStats(name: string): Effect.Effect<BuilderStats | null>
}

export class BuildersService extends Context.Tag("BuildersService")<
  BuildersService,
  BuildersServiceShape
>() {}

// ── Implementation ───────────────────────────────────────────────────

const makeBuildersService = (
  hcloud: HcloudService["Type"],
  tailscale: TailscaleService["Type"],
  ssh: SshService["Type"],
  croc: CrocService["Type"],
  fs: FileSystem.FileSystem,
  lock: LockServiceShape,
): BuildersServiceShape => {
  const isReady = (name: string): Effect.Effect<boolean, BuilderNotFoundError> =>
    Effect.gen(function* () {
      const exists = yield* hcloud.serverExists(name).pipe(
        Effect.catchAll(() => Effect.succeed(false))
      )
      if (!exists) {
        return yield* Effect.fail(new BuilderNotFoundError({ name }))
      }
      return yield* tailscale.resolveIP(name).pipe(
        Effect.flatMap((ip) => tailscale.isReachable(ip, 22)),
        Effect.catchAll(() => Effect.succeed(false)),
      )
    })

  /**
   * If the builder is ready, return true (no action needed).
   * If not ready and young (< 15 min), poll until ready or timeout.
   * If still not ready (stale or timed out), destroy it and return false.
   */
  const ensureReadyOrDestroy = (name: string): Effect.Effect<boolean, BuilderDestroyError> =>
    Effect.gen(function* () {
      const status = yield* isReady(name).pipe(
        Effect.map((r) => r ? "ready" as const : "not-ready" as const),
        // Server gone — nothing to destroy
        Effect.catchTag("BuilderNotFoundError", () => Effect.succeed("gone" as const))
      )
      if (status !== "not-ready") return status === "ready"

      const ageHours = yield* hcloud.getServer(name).pipe(
        Effect.map((s) => calculateUptimeHours(s.created)),
        Effect.catchAll(() => Effect.succeed(0)),
      )
      const ageMinutes = ageHours * 60

      if (ageMinutes < 15) {
        yield* Effect.log(`${name} exists but is not ready (${Math.round(ageMinutes)}m old), waiting...`)
        const becameReady = yield* isReady(name).pipe(
          Effect.catchTag("BuilderNotFoundError", () => Effect.succeed("gone" as const)),
          Effect.flatMap((r): Effect.Effect<true | "gone", "not ready"> =>
            r === "gone" ? Effect.succeed("gone") : r ? Effect.succeed(true) : Effect.fail("not ready")
          ),
          Effect.retry(Schedule.spaced("5 seconds").pipe(Schedule.upTo("15 minutes"))),
          Effect.catchAll(() => Effect.succeed(false as const)),
        )
        if (becameReady === true) {
          yield* Effect.log(`${name} is now ready`)
          return true
        }
        if (becameReady === "gone") {
          yield* Effect.log(`${name} was destroyed externally`)
          return false
        }
      }

      yield* Effect.log(`${name} is not ready, destroying...`)
      yield* destroy(name)
      return false
    })

  const destroy = (name: string): Effect.Effect<void, BuilderDestroyError> =>
    Effect.uninterruptible(Effect.gen(function* () {
      // Delete server (wait for it to be fully gone)
      yield* hcloud.deleteServer(name, { wait: true }).pipe(
        Effect.catchAll((err) =>
          Effect.fail(new BuilderDestroyError({
            name,
            message: "Failed to delete server",
            cause: err,
          }))
        )
      )

      // Delete headscale node (best-effort)
      yield* tailscale.deleteNode(name).pipe(
        Effect.catchAll(() => Effect.logWarning(`Failed to remove ${name} from headscale`))
      )
    }))

  return {
  resolve: (rawName) => {
    const name = normalizeName(rawName)
    if (!isBuilderName(name)) {
      return Effect.fail(new InvalidBuilderNameError({ input: rawName }))
    }
    return Effect.succeed(name)
  },

  list: () =>
    hcloud.listServers().pipe(
      Effect.map(servers =>
        servers
          .filter(s => BUILDER_CONFIG.builderPattern.test(s.name))
          .sort((a, b) => a.name.localeCompare(b.name))
      ),
    ),

  get: (name) =>
    hcloud.getServer(name).pipe(
      Effect.catchAll(() => Effect.fail(new BuilderNotFoundError({ name })))
    ),

  exists: (name) =>
    hcloud.serverExists(name).pipe(
      Effect.catchAll(() => Effect.succeed(false))
    ),

  resolveIP: (name) =>
    tailscale.resolveIP(name).pipe(
      Effect.catchAll((err) =>
        Effect.fail(new BuilderUnreachableError({
          name,
          reason: "Tailscale IP resolution failed",
          cause: err,
        }))
      )
    ),

  isReady,

  getAge: (name) =>
    hcloud.getServer(name).pipe(
      Effect.map((server) => calculateUptimeHours(server.created)),
      Effect.catchAll(() => Effect.fail(new BuilderNotFoundError({ name }))),
    ),

  destroy,

  create: (name) =>
    Effect.gen(function* () {
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
    }),

  getStats: (name) =>
    Effect.gen(function* () {
      // Look up server to get creation time for uptime
      const serverResult = yield* hcloud.getServer(name).pipe(Effect.either)
      if (Either.isLeft(serverResult)) return null
      const uptimeHours = calculateUptimeHours(serverResult.right.created)

      // Try to resolve IP, return null if unreachable
      const ipResult = yield* tailscale.resolveIP(name).pipe(Effect.either)
      if (Either.isLeft(ipResult)) return null
      const ip = ipResult.right

      // Try to run stats command via SSH
      const sshResult = yield* ssh.exec(ip, REMOTE_STATS_CMD, {
        port: BUILDER_CONFIG.sshPort,
        connectTimeout: 10,
      }).pipe(Effect.either)
      if (Either.isLeft(sshResult)) return null

      // Parse output — parseStats throws on bad input
      const parsed = yield* Effect.try({
        try: () => parseStats(name, sshResult.right.stdout),
        catch: () => new Error("Failed to parse stats output"),
      }).pipe(Effect.catchAll(() => Effect.succeed(null as BuilderStats | null)))

      if (parsed) {
        parsed.uptimeHours = uptimeHours
      }

      return parsed
    }),
  }
}

// ── Layer ────────────────────────────────────────────────────────────

export const BuildersLive = Layer.effect(
  BuildersService,
  Effect.gen(function* () {
    const hcloud = yield* HcloudService
    const tailscale = yield* TailscaleService
    const sshSvc = yield* SshService
    const croc = yield* CrocService
    const fileSystem = yield* FileSystem.FileSystem
    const lockSvc = yield* LockService
    return makeBuildersService(hcloud, tailscale, sshSvc, croc, fileSystem, lockSvc)
  })
)
