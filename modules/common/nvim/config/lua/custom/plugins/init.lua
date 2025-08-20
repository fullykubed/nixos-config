-- This file makes the custom/plugins directory work as a module
-- It returns all the plugin configurations from this directory

return {
  require("custom.plugins.autosave"),
  require("custom.plugins.vim-tmux-navigator"),
}
