import type { BooleanFlag, CommandGroup } from "./types"
import { buildersGroup } from "../commands/builders/index"
import { devGroup } from "../commands/dev/index"
import { muxGroup } from "../commands/mux/index"

const globalFlags: readonly BooleanFlag[] = [
  {
    kind: "boolean",
    name: "json",
    description: "Output structured JSON instead of human-readable format",
    default: false
  },
  {
    kind: "boolean",
    name: "help",
    short: "h",
    description: "Show help information",
    default: false
  }
] as const

const groups = new Map<string, CommandGroup<unknown>>([
  ["builders", buildersGroup],
  ["mux", muxGroup]
])

if (process.env.J_PRODUCTION !== "1") {
  groups.set("dev", devGroup)
}

export const registry = {
  groups,
  globalFlags
}