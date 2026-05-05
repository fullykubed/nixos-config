import { Effect } from "effect"
import type { Parsed } from "./command"
import { BuildersService } from "../../../services/Builders"
import { json } from "../../../lib/output"
import { getConfirmation } from "./get-confirmation"

/**
 * Destroy all builders
 */
export const destroyAllBuilders = (parsed: Parsed) =>
  Effect.gen(function* () {
    const svc = yield* BuildersService
    const isJson = parsed.flags.json
    const skipConfirmation = parsed.flags.yes

    const servers = yield* svc.list()
    const builderNames = servers.map(s => s.name)

    if (builderNames.length === 0) {
      if (isJson) {
        json({ status: "success", message: "No builders to destroy", destroyed: [] })
      } else {
        yield* Effect.log("No builders to destroy")
      }
      return
    }

    if (!isJson) {
      yield* Effect.logWarning(`WARNING: This will destroy the following builders:`)
      for (const name of builderNames) {
        yield* Effect.log(`  ${name}`)
      }
      yield* Effect.log("")
    }

    // Get confirmation
    const confirmed = yield* getConfirmation(skipConfirmation)

    if (!confirmed) {
      if (isJson) {
        json({ status: "cancelled", message: "Operation cancelled", builders: builderNames })
      } else {
        yield* Effect.log("Aborted.")
      }
      return
    }

    // Destroy each builder
    const destroyed: string[] = []
    const failed: { name: string; error: string }[] = []

    for (const name of builderNames) {
      yield* svc.destroy(name).pipe(
        Effect.tap(() => {
          destroyed.push(name)
          if (!isJson) {
            return Effect.log(`Destroyed ${name}`)
          }
          return Effect.void
        }),
        Effect.catchAll(err => {
          failed.push({ name, error: String(err) })
          if (!isJson) {
            return Effect.logError(`Failed to destroy ${name}: ${String(err)}`)
          }
          return Effect.succeed(undefined)
        })
      )
    }

    if (isJson) {
      json({
        status: failed.length === 0 ? "success" : "partial",
        message: `Destroyed ${destroyed.length}/${builderNames.length} builders`,
        destroyed,
        failed
      })
    } else {
      if (destroyed.length === builderNames.length) {
        yield* Effect.log(`All builders destroyed`)
      } else {
        yield* Effect.logWarning(`Destroyed ${destroyed.length}/${builderNames.length} builders`)
      }
    }
  })
