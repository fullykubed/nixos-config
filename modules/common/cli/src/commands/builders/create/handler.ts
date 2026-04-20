import { Effect } from "effect"
import type { ParsedCommand } from "../../../cli/types"
import { BuildersService } from "../../../services/Builders"

export const createHandler = (parsed: ParsedCommand) =>
  Effect.gen(function* () {
    const builders = yield* BuildersService

    const rawName = parsed.args[0]!
    const name = yield* builders.resolve(rawName)
    yield* builders.create(name)
  })
