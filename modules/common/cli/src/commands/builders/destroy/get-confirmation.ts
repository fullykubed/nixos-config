import * as readline from "node:readline"
import { Effect } from "effect"

/**
 * Get user confirmation for destroy-all
 */
export const getConfirmation = (skipConfirmation: boolean): Effect.Effect<boolean> => {
  if (skipConfirmation) {
    return Effect.succeed(true)
  }

  return Effect.tryPromise({
    try: async () => {
      const rl = readline.createInterface({
        input: process.stdin,
        output: process.stdout
      })

      const answer = await new Promise<string>((resolve) => {
        rl.question("Type 'yes' to confirm: ", (ans: string) => {
          rl.close()
          resolve(ans)
        })
      })

      return answer === "yes"
    },
    catch: () => new Error("Failed to read confirmation")
  }).pipe(
    Effect.catchAll(() => Effect.succeed(false))
  )
}
