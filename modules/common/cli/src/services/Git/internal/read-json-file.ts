import { Effect } from "effect"
import { FileSystem } from "@effect/platform"
import { ProjectConfigParseError } from "../errors"

/**
 * Read and parse a JSON file, returning an empty object if the file doesn't exist or can't be read.
 */
export const readJsonFile = (path: string) =>
  Effect.gen(function* () {
    const fs = yield* FileSystem.FileSystem

    const exists = yield* fs.exists(path).pipe(
      Effect.catchAll(() => Effect.succeed(false))
    )
    if (!exists) return {}

    const content = yield* fs.readFileString(path).pipe(
      Effect.catchAll(() => Effect.succeed(null))
    )
    if (content === null) return {}

    return yield* Effect.try({
      try: () => JSON.parse(content) as Record<string, unknown>,
      catch: (e) => new ProjectConfigParseError({
        path,
        message: e instanceof Error ? e.message : String(e),
      }),
    })
  })
