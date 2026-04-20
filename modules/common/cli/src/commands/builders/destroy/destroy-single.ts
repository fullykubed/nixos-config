import { Effect } from "effect"
import { BuildersService } from "../../../services/Builders"
import { json } from "../../../lib/output"

/**
 * Destroy a single builder
 */
export const destroySingleBuilder = (name: string, isJson: boolean) =>
  Effect.gen(function* () {
    const builders = yield* BuildersService

    // Check if server exists
    const serverExists = yield* builders.exists(name)

    if (!serverExists) {
      if (isJson) {
        json({ status: "error", message: "Builder does not exist", name })
      } else {
        yield* Effect.logWarning(`Builder ${name} does not exist`)
      }
      return
    }

    yield* builders.destroy(name).pipe(
      Effect.catchTag("BuilderDestroyError", (err) => {
        if (isJson) {
          json({ status: "error", message: "Failed to delete server", name, error: err.message })
        }
        return Effect.logError(`Failed to destroy ${name}: ${err.message}`).pipe(
          Effect.andThen(Effect.fail(err))
        )
      })
    )

    if (isJson) {
      json({ status: "success", message: "Builder destroyed", name })
    } else {
      yield* Effect.log(`Destroyed ${name}`)
    }
  })
