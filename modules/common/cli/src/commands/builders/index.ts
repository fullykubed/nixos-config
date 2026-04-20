import { commandMap } from "../../cli/types"
import { checkCommand } from "./check/command"
import { cleanupCommand } from "./cleanup/command"
import { createCommand } from "./create/command"
import { dashboardCommand } from "./dashboard/command"
import { destroyCommand } from "./destroy/command"
import { ensureCommand } from "./ensure/command"
import { listCommand } from "./list/command"
import { pollStatusCommand } from "./poll-status/command"
import { sshCommand } from "./ssh/command"
import { statusCommand } from "./status/command"

/**
 * Builders command group.
 * Individual commands are added as they are implemented.
 */
export const buildersGroup = {
  name: "builders",
  description: "Manage remote builder VMs",
  commands: commandMap([
    ["check", checkCommand],
    ["cleanup", cleanupCommand],
    ["create", createCommand],
    ["dashboard", dashboardCommand],
    ["destroy", destroyCommand],
    ["ensure", ensureCommand],
    ["list", listCommand],
    ["poll-status", pollStatusCommand],
    ["ssh", sshCommand],
    ["status", statusCommand]
  ])
}
