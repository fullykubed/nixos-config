import { Effect } from "effect"
import type { Parsed } from "./command"
import { BuildersService } from "../../../services/Builders"
import { json } from "../../../lib/output"
import { destroySingleBuilder } from "./destroy-single"
import { destroyAllBuilders } from "./destroy-all-handler"

export const destroyHandler = (parsed: Parsed) =>
  Effect.gen(function* () {
    const isJson = parsed.flags.json
    const all = parsed.flags.all
    const nameArg = parsed.args.name

    if (all) {
      yield* destroyAllBuilders(parsed)
    } else {
      if (!nameArg) {
        if (isJson) {
          json({ status: "error", message: "Builder name is required" })
        } else {
          yield* Effect.logError("Usage: j builders destroy <name|N> or j builders destroy -a")
        }
        return
      }

      const builders = yield* BuildersService
      const name = yield* builders.resolve(nameArg)
      yield* destroySingleBuilder(name, isJson)
    }
  })
