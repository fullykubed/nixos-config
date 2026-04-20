import { Effect } from "effect"
import { defineCommand } from "../../../cli/types"
import { BuildersFullLive } from "../../../services/layers"
import { sshHandler } from "./handler"

export const sshCommand = defineCommand({
  name: "ssh",
  description: "SSH into a builder VM",
  flags: [
    { kind: "boolean", name: "root", description: "Connect as root instead of remotebuild", default: false }
  ],
  args: [
    { name: "name", description: "Builder name or number", required: true }
  ],
  handler: (parsed) => sshHandler(parsed).pipe(Effect.provide(BuildersFullLive))
})
