import { Effect, Option } from "effect"
import type {} from "../errors"
import type {} from "../types"
import { listWindows } from "./list-windows"

/**
 * Find a tmux window by name pattern. Returns Some(window) if found, None if not found.
 */
export const findWindow = (namePattern: string) =>
  Effect.gen(function* () {
    const windows = yield* listWindows()
    const pattern = new RegExp(namePattern, "i") // Case-insensitive search
    return Option.fromNullable(windows.find((w) => pattern.test(w.name)))
  })