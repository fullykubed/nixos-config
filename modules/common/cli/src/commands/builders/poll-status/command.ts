import { Effect } from "effect"
import { defineCommand } from "../../../cli/types"
import { BuildersFullLive } from "../../../services/layers"
import { pollStatusHandler } from "./handler"

export const pollStatusCommand = defineCommand({
  name: "poll-status",
  description: "Poll builder metrics and write status JSON (systemd oneshot)",
  flags: [],
  args: [],
  handler: (parsed) => pollStatusHandler(parsed).pipe(Effect.provide(BuildersFullLive))
})
