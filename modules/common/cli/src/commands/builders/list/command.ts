import { Effect } from "effect"
import { defineCommand } from "../../../cli/types"
import { BuildersFullLive } from "../../../services/layers"
import { listHandler } from "./handler"

export const listCommand = defineCommand({
  name: "list",
  description: "List all active builder VMs",
  flags: [
    {
      kind: "boolean",
      name: "json",
      description: "Output results as JSON",
      default: false
    }
  ],
  args: [],
  handler: (parsed) => listHandler(parsed).pipe(Effect.provide(BuildersFullLive))
})
