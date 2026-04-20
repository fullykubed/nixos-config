import { Effect } from "effect"
import { defineCommand } from "../../../cli/types"
import { BuildersFullLive } from "../../../services/layers"
import { createHandler } from "./handler"

export const createCommand = defineCommand({
  name: "create",
  description: "Create a new remote builder VM",
  flags: [],
  args: [{ name: "name", description: "Builder name (e.g., 1, big-1, builder-1)", required: true }],
  handler: (parsed) => createHandler(parsed).pipe(Effect.provide(BuildersFullLive))
})
