import { Effect } from "effect"
import { defineCommand } from "../../../cli/types"
import { BuildersFullLive } from "../../../services/layers"
import { statusHandler } from "./handler"

export const statusCommand = defineCommand({
  name: "status",
  description: "Show builder status summary with cost breakdown",
  flags: [
    {
      kind: "boolean",
      name: "json",
      description: "Output in JSON format",
      default: false
    }
  ],
  args: [],
  handler: (parsed) => statusHandler(parsed).pipe(Effect.provide(BuildersFullLive))
})
