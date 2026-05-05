import { Effect } from "effect"
import { defineCommand, type TypedParsed } from "../../../cli/types"

const sshFlags = [
  { kind: "boolean", name: "root", description: "Connect as root instead of remotebuild", default: false }
] as const

const sshArgs = [
  { name: "name", description: "Builder name or number", required: true }
] as const

export type Parsed = TypedParsed<typeof sshFlags, typeof sshArgs>

export const sshCommand = defineCommand({
  name: "ssh",
  description: "SSH into a builder VM",
  flags: sshFlags,
  args: sshArgs,
  handler: (parsed) =>
    Effect.gen(function* () {
      const [{ sshHandler }, { BuildersFullLive }] = yield* Effect.all([
        Effect.promise(() => import("./handler")),
        Effect.promise(() => import("../../../services/layers"))
      ], { concurrency: "unbounded" })
      yield* sshHandler(parsed).pipe(Effect.provide(BuildersFullLive))
    })
})
