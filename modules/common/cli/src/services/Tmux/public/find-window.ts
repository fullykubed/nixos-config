import { Effect } from "effect"
import type {} from "../errors"
import type {} from "../types"
import { listWindows } from "./list-windows"

/**
 * Find a tmux window by name pattern. Returns the first matching window or null if not found.
 */
export const findWindow = (namePattern: string) =>
  Effect.gen(function* () {
    const windows = yield* listWindows()
    const pattern = new RegExp(namePattern, "i") // Case-insensitive search

    for (const window of windows) {
      if (pattern.test(window.name)) {
        return window
      }
    }

    return null
  })