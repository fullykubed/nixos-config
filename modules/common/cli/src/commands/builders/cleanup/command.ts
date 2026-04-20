import { Effect } from "effect"
import { defineCommand } from "../../../cli/types"
import { HcloudFullLive } from "../../../services/layers"
import { cleanupHandler } from "./handler"

export const cleanupCommand = defineCommand({
  name: "cleanup",
  description: "Delete old builder snapshots, keeping only the latest",
  flags: [
    {
      kind: "boolean",
      name: "yes",
      short: "y",
      description: "Skip confirmation prompt",
      default: false
    }
  ],
  args: [],
  handler: (parsed) => cleanupHandler(parsed).pipe(Effect.provide(HcloudFullLive))
})
