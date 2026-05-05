import { Effect } from "effect"
import { defineCommand } from "../../../cli/types"

export const pingCommand = defineCommand({
  name: "ping",
  description: "Print a message (useful for measuring startup time)",
  flags: [],
  args: [],
  handler: () => Effect.log("pong")
})
