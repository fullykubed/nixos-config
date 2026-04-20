import { Effect, Schedule } from "effect"
import { TailscaleService } from "../../../services/Tailscale"

/**
 * Wait for builder to become reachable with polling
 */
export const waitForBuilder = (hostname: string, port: string, maxSeconds: number) =>
  Effect.gen(function* () {
    const tailscale = yield* TailscaleService
    const maxAttempts = Math.floor(maxSeconds / 5)

    yield* Effect.log(`:: Waiting for ${hostname}:${port} to be reachable (max ${maxSeconds}s)...`)

    const checkOnce = tailscale.isReachable(hostname, Number(port)).pipe(
      Effect.flatMap((reachable) =>
        reachable
          ? Effect.succeed(undefined)
          : Effect.fail(new Error("not reachable yet"))
      )
    )

    yield* checkOnce.pipe(
      Effect.retry(
        Schedule.spaced("5 seconds").pipe(
          Schedule.intersect(Schedule.recurs(maxAttempts - 1)),
          Schedule.tapInput(() =>
            Effect.log(`::   not reachable yet, retrying in 5s...`)
          )
        )
      ),
      Effect.mapError(() => new Error(`Timeout: ${hostname}:${port} not reachable after ${maxSeconds}s`))
    )

    yield* Effect.log(`:: ${hostname}:${port} reachable`)
  })
