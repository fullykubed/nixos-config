import { Effect } from "effect"
import type { Parsed } from "./command"
import { BuildersService } from "../../../services/Builders"

export const createHandler = (parsed: Parsed) =>
  Effect.gen(function* () {
    const builders = yield* BuildersService

    const name = yield* builders.resolve(parsed.args.name)
    yield* builders.create(name)
  })
