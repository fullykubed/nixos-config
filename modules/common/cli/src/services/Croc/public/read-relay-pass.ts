import { Effect } from "effect"
import { FileSystem } from "@effect/platform"
import { CrocRelayPassError } from "../errors"
import { RELAY_PASS_PATH } from "../config"

export const readRelayPass = () =>
  Effect.gen(function* () {
    const fs = yield* FileSystem.FileSystem
    return yield* fs.readFileString(RELAY_PASS_PATH).pipe(
      Effect.map(text => text.trim()),
      Effect.catchAll(() => Effect.fail(new CrocRelayPassError({
        path: RELAY_PASS_PATH,
        message: `Failed to read croc relay password from ${RELAY_PASS_PATH}`
      })))
    )
  })