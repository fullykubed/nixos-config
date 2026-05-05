import { Effect } from "effect"
import { normalizeName, isBuilderName } from "../internal/helpers"
import { InvalidBuilderNameError } from "../errors"

/**
 * Normalize and validate a raw builder name input.
 * "1" → "builder-1", "big-2" → "big-builder-2", etc.
 */
export const resolve = (rawName: string) => {
  const name = normalizeName(rawName)
  if (!isBuilderName(name)) {
    return Effect.fail(new InvalidBuilderNameError({ input: rawName }))
  }
  return Effect.succeed(name)
}
