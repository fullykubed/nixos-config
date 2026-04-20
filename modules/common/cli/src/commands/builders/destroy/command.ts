import { Effect } from "effect"
import { defineCommand } from "../../../cli/types"
import { BuildersFullLive } from "../../../services/layers"
import { destroyHandler } from "./destroy-handler"

export const destroyCommand = defineCommand({
  name: "destroy",
  description: "Destroy a builder VM",
  flags: [
    { kind: "boolean", name: "all", short: "a", description: "Destroy all builders", default: false },
    { kind: "boolean", name: "yes", short: "y", description: "Skip confirmation prompt", default: false },
    { kind: "boolean", name: "json", description: "Output results as JSON", default: false }
  ],
  args: [{ name: "name", description: "Builder name (optional with -a)", required: false }],
  handler: (parsed) => destroyHandler(parsed).pipe(Effect.provide(BuildersFullLive))
})
