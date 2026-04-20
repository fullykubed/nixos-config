import { Effect, Exit } from "effect"
import type { ParsedCommand } from "../../../cli/types"
import { BuildersService } from "../../../services/Builders"
import { TailscaleService } from "../../../services/Tailscale"
import { waitForBuilder } from "./wait-for-builder"
import { withLock } from "./with-lock"
import { serverExists } from "./server-exists"

const BUILDER_WAIT_TIMEOUT = 900 // 15 minutes

export const ensureHandler = (parsed: ParsedCommand) =>
  Effect.gen(function* () {
    const hostname = parsed.args[0]
    const port = parsed.args[1]

    if (!hostname || !port) {
      return yield* Effect.fail(new Error("Usage: j builders ensure <hostname> <port>"))
    }

    const tailscale = yield* TailscaleService
    const builders = yield* BuildersService

    // Fast path: if builder is already reachable, exit immediately
    const fastCheck = yield* tailscale.isReachable(hostname, Number(port))
    if (fastCheck) {
      return
    }

    yield* Effect.log(`:: Builder ${hostname} not reachable`)

    // Slow path: acquire lock and provision if needed
    const lockName = `ensure-builder-${hostname}`

    yield* withLock(lockName, () => Effect.gen(function* () {
      let weCreated = false

      // Re-check reachability after acquiring lock
      const recheckReachable = yield* tailscale.isReachable(hostname, Number(port))
      if (recheckReachable) {
        return
      }

      // Check if server exists in Hetzner
      const exists = yield* serverExists(hostname)

      if (!exists) {
        weCreated = true
        yield* builders.create(hostname).pipe(
          Effect.catchTag("BuilderCreateError", (error) => {
            // Check if another machine created it concurrently
            return serverExists(hostname).pipe(
              Effect.flatMap((nowExists) => {
                if (nowExists) {
                  weCreated = false
                  return Effect.log(`:: Builder ${hostname} was created by another machine, waiting for it...`)
                } else {
                  return Effect.fail(error)
                }
              })
            )
          })
        )
      } else {
        yield* Effect.log(`:: Builder ${hostname} exists in Hetzner but is not reachable yet, waiting...`)
      }

      // Wait for builder to become reachable
      yield* waitForBuilder(hostname, port, BUILDER_WAIT_TIMEOUT).pipe(
        Effect.onExit((exit) =>
          !weCreated || Exit.isSuccess(exit)
            ? Effect.void
            : Effect.uninterruptible(
                Effect.log(`:: Cleaning up: destroying partially-provisioned ${hostname}`).pipe(
                  Effect.andThen(
                    builders.destroy(hostname).pipe(
                      Effect.catchAll(() => Effect.succeed(undefined))
                    )
                  )
                )
              )
        )
      )
    }))
  })
