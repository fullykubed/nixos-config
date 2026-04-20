import { Effect } from "effect"
import { defineCommand } from "../../../cli/types"
import { BuildersFullLive } from "../../../services/layers"
import { ensureHandler } from "./handler"

export const ensureCommand = defineCommand({
  name: "ensure",
  description: "Ensure a builder exists and is reachable (SSH Match exec)",
  flags: [],
  args: [
    { name: "hostname", description: "Builder hostname", required: true },
    { name: "port", description: "SSH port to check", required: true }
  ],
  handler: (parsed) => ensureHandler(parsed).pipe(Effect.provide(BuildersFullLive))
})
