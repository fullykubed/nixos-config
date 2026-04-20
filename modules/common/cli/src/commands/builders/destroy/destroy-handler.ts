import { Effect } from "effect"
import type { ParsedCommand } from "../../../cli/types"
import { BuildersService } from "../../../services/Builders"
import { json } from "../../../lib/output"
import { destroySingleBuilder } from "./destroy-single"
import { destroyAllBuilders } from "./destroy-all-handler"

export const destroyHandler = (parsed: ParsedCommand) =>
  Effect.gen(function* () {
    const isJson = parsed.flags.get("json") === true
    const all = parsed.flags.get("all") === true
    const nameArg = parsed.args[0]

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
