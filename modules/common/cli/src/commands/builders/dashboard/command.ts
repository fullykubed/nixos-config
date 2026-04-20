import { Effect } from "effect"
import { defineCommand } from "../../../cli/types"
import { BuildersFullLive } from "../../../services/layers"
import { dashboardHandler } from "./handler"

export const dashboardCommand = defineCommand({
  name: "dashboard",
  description: "Live-updating resource dashboard for all builders",
  flags: [],
  args: [],
  handler: (parsed) => dashboardHandler(parsed).pipe(Effect.provide(BuildersFullLive))
})
