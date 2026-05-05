import { Effect } from "effect"
import { defineCommand } from "../../../cli/types"
import { BranchName, ProjectId } from "../../../services/Git/types"

export const echoCommand = defineCommand({
  name: "echo",
  description: "Echo branded arguments back (for testing validation)",
  flags: [
    { kind: "string", name: "project-id", short: "p", description: "A project UUID", required: false, brand: ProjectId } as const,
  ],
  args: [
    { name: "branch", description: "A git branch name", required: false, brand: BranchName },
  ],
  handler: (parsed) =>
    Effect.gen(function* () {
      if (parsed.args.branch) yield* Effect.log(`branch: ${parsed.args.branch}`)
      if (parsed.flags["project-id"]) yield* Effect.log(`project-id: ${parsed.flags["project-id"]}`)
      if (!parsed.args.branch && !parsed.flags["project-id"]) yield* Effect.log("(no arguments provided)")
    }),
})
