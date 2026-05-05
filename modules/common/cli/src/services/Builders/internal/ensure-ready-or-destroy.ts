import { Effect, Schedule } from "effect"
import { HcloudService } from "../../Hcloud"
import { calculateUptimeHours } from "./calculate-uptime"
import { isReady } from "../public/is-ready"
import { destroy } from "../public/destroy"

/**
 * If the builder is ready, return true (no action needed).
 * If not ready and young (< 15 min), poll until ready or timeout.
 * If still not ready (stale or timed out), destroy it and return false.
 */
export const ensureReadyOrDestroy = (name: string) =>
  Effect.gen(function* () {
    const hcloud = yield* HcloudService

    const status = yield* isReady(name).pipe(
      Effect.map((r) => r ? "ready" as const : "not-ready" as const),
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
        Effect.flatMap((r) => {
          if (r === "gone") return Effect.succeed("gone" as const)
          if (r) return Effect.succeed("ready" as const)
          return Effect.fail("not ready" as const)
        }),
        Effect.retry(Schedule.spaced("5 seconds").pipe(Schedule.upTo("15 minutes"))),
        Effect.catchAll(() => Effect.succeed(false as const)),
      )
      if (becameReady === "ready") {
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
