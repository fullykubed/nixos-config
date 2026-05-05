import { Effect } from "effect"
import { FileSystem } from "@effect/platform"
import { HeadscalePreAuthError } from "../errors"
import { HEADSCALE_API_KEY_PATH } from "../config"

export const readHeadscaleApiKey = () =>
  Effect.gen(function* () {
    const fs = yield* FileSystem.FileSystem
    return yield* fs.readFileString(HEADSCALE_API_KEY_PATH).pipe(
      Effect.map(text => text.trim()),
      Effect.catchAll(() => Effect.fail(new HeadscalePreAuthError({
        message: `Failed to read headscale API key from ${HEADSCALE_API_KEY_PATH}`
      })))
    )
  })