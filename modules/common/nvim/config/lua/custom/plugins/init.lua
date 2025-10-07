-- This file makes the custom/plugins directory work as a module
-- It returns all the plugin configurations from this directory

return {
  require("custom.plugins.autosave"),
  require("custom.plugins.vim-tmux-navigator"),
  require("custom.plugins.comment"),
  require("custom.plugins.guess-indent"),
  require("custom.plugins.mini-splitjoin"),
  require("custom.plugins.mini-move"),
  require("custom.plugins.coerce"),
  require("custom.plugins.numb"),
  require("custom.plugins.various-textobjs"),
  require("custom.plugins.telescope-insert-path"),
  require("custom.plugins.precognition"),
  require("custom.plugins.treesitter-textobjects"),
  require("custom.plugins.treesitter-context"),
  require("custom.plugins.tiny-glimmer"),
  require("custom.plugins.neoscroll"),
  require("custom.plugins.smear-cursor"),
  require("custom.plugins.neotest"),
  require("custom.plugins.navbuddy"),
  require("custom.plugins.spectre"),
  require("custom.plugins.trouble"),
  require("custom.plugins.lazygit"),
}
