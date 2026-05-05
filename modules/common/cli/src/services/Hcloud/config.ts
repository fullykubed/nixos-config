import { Config, Context, Effect, Either } from "effect"
import { FileSystem } from "@effect/platform"
import { HcloudTokenError } from "./errors"

export interface HcloudConfigShape {
  readonly apiBaseUrl: string
  readonly token: Effect.Effect<string>
}

export class HcloudConfig extends Context.Tag("HcloudConfig")<
  HcloudConfig,
  HcloudConfigShape
>() {}

export const loadHcloudConfig = Effect.gen(function* () {
  const apiBaseUrl = yield* Config.string("HETZNER_API").pipe(Config.withDefault("https://api.hetzner.cloud/v1"))
  const tokenPath = yield* Config.string("HETZNER_TOKEN_PATH").pipe(Config.withDefault("/run/agenix/hetzner-api-token"))
  const hcloudToken = Config.string("HCLOUD_TOKEN")
  const fs = yield* FileSystem.FileSystem

  const token = Effect.cached(
    Effect.either(hcloudToken).pipe(
      Effect.flatMap(either =>
        Either.isLeft(either)
          ? fs.readFileString(tokenPath).pipe(Effect.map(s => s.trim()))
          : Effect.succeed(either.right)
      ),
      Effect.catchAll(() => Effect.die(new HcloudTokenError({
        message: `HCLOUD_TOKEN not set and ${tokenPath} not readable`
      }))),
    )
  ).pipe(Effect.flatten)

  return { apiBaseUrl, token }
})
