import { commandMap } from "../../cli/types"
import { createCommand } from "./create/command"
import { removeCommand } from "./remove/command"
import { mergeCommand } from "./merge/command"
import { showConfigCommand } from "./show-config/command"
import { hookCommand } from "./_hook/command"

export const muxGroup = {
  name: "mux",
  description: "Manage git worktrees with tmux windows",
  commands: commandMap([
    ["create", createCommand],
    ["remove", removeCommand],
    ["merge", mergeCommand],
    ["show-config", showConfigCommand],
    ["_hook", hookCommand],
  ]),
}