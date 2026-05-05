import { commandMap } from "../../cli/types"
import { echoCommand } from "./echo/command"
import { pingCommand } from "./ping/command"

/**
 * Dev-only command group.
 * Available when running via `bun src/main.ts` but excluded from the
 * compiled production binary (guarded by process.env.J_PRODUCTION).
 */
export const devGroup = {
  name: "dev",
  description: "Development-only commands",
  commands: commandMap([
    ["echo", echoCommand],
    ["ping", pingCommand],
  ])
}
