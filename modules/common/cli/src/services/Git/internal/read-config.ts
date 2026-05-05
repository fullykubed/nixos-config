import { Effect, Schema } from "effect"
import { FileSystem, Path } from "@effect/platform"
import { ProjectConfigSchema } from "../config-types"
import { DEFAULT_CONFIG } from "../config-defaults"
import { ProjectConfigParseError } from "../errors"

const CONFIG_FILENAME = "project.json"

export const readConfig = (repoRoot: string) =>
  Effect.gen(function* () {
    const fs = yield* FileSystem.FileSystem
    const path = yield* Path.Path

    // Try repo root first, then .bare directory
    const candidates = [
      path.join(repoRoot, CONFIG_FILENAME),
      path.join(repoRoot, ".bare", CONFIG_FILENAME),
    ]

    let configPath: string | null = null
    for (const candidate of candidates) {
      if (yield* fs.exists(candidate)) {
        configPath = candidate
        break
      }
    }

    if (configPath === null) return DEFAULT_CONFIG

    const content = yield* fs.readFileString(configPath).pipe(
      Effect.catchAll(() => Effect.succeed(null))
    )
    if (content === null) return DEFAULT_CONFIG

    const json = yield* Effect.try({
      try: () => JSON.parse(content) as unknown,
      catch: (e) => new ProjectConfigParseError({
        path: configPath,
        message: e instanceof Error ? e.message : String(e),
      }),
    })

    return yield* Schema.decodeUnknown(ProjectConfigSchema)(json).pipe(
      Effect.catchTag("ParseError", (e) =>
        Effect.fail(new ProjectConfigParseError({
          path: configPath,
          message: e.message,
        }))
      ),
    )
  })
