import { commandMap } from "../../cli/types"
import { createCommand } from "./create/command"
import { listCommand } from "./list/command"
import { removeCommand } from "./remove/command"
import { mergeCommand } from "./merge/command"
import { hookCommand } from "./_hook/command"

export const muxGroup = {
  name: "mux",
  description: "Manage git worktrees with tmux windows",
  commands: commandMap([
    ["create", createCommand],
    ["list", listCommand],
    ["remove", removeCommand],
    ["merge", mergeCommand],
    ["_hook", hookCommand],
  ]),
}