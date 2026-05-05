import { Effect } from "effect"
import { defineCommand, type TypedParsed } from "../../../cli/types"

const checkFlags = [
  {
    kind: "boolean",
    name: "nix",
    description: "Check Nix version",
    default: false
  },
  {
    kind: "boolean",
    name: "hw",
    description: "Check CPU and memory info",
    default: false
  },
  {
    kind: "boolean",
    name: "cpu",
    description: "Run CPU benchmark (~30s)",
    default: false
  },
  {
    kind: "boolean",
    name: "net",
    description: "Run network benchmark (~30s)",
    default: false
  },
  {
    kind: "boolean",
    name: "disk",
    description: "Check disk space and run fio benchmark (~30s)",
    default: false
  },
  {
    kind: "boolean",
    name: "tailscale",
    description: "Check Tailscale status on builder",
    default: false
  },
  {
    kind: "boolean",
    name: "ccache",
    description: "Check ccache mount, sync, and stats",
    default: false
  },
  {
    kind: "boolean",
    name: "shutdown",
    description: "Check auto-shutdown countdown",
    default: false
  },
  {
    kind: "boolean",
    name: "json",
    description: "Output results in JSON format",
    default: false
  }
] as const

const checkArgs = [
  {
    name: "name",
    description: "Builder name or number",
    required: true
  }
] as const

export type Parsed = TypedParsed<typeof checkFlags, typeof checkArgs>

export const checkCommand = defineCommand({
  name: "check",
  description: "Run health checks on a builder",
  flags: checkFlags,
  args: checkArgs,
  handler: (parsed) =>
    Effect.gen(function* () {
      const [{ checkHandler }, { BuildersFullLive }] = yield* Effect.all([
        Effect.promise(() => import("./handler")),
        Effect.promise(() => import("../../../services/layers"))
      ], { concurrency: "unbounded" })
      yield* checkHandler(parsed).pipe(Effect.provide(BuildersFullLive))
    })
})
