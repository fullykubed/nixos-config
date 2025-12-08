-- This file makes the custom/plugins directory work as a module
-- It returns all the plugin configurations from this directory

-- Helper function to flatten nested plugin specs
local function flatten_plugins(...)
  local result = {}
  for _, item in ipairs({...}) do
    if type(item) == "table" then
      -- Check if it's a plugin spec (has a [1] that's a string) or a list of specs
      if type(item[1]) == "string" then
        -- Single plugin spec
        table.insert(result, item)
      else
        -- List of plugin specs
        for _, plugin in ipairs(item) do
          table.insert(result, plugin)
        end
      end
    end
  end
  return result
end

return flatten_plugins(
  require("custom.plugins.theme"),
  require("custom.plugins.telescope"),
  require("custom.plugins.lsp"),
  require("custom.plugins.blink"),
  require("custom.plugins.conform"),
  require("custom.plugins.todo-comments"),
  require("custom.plugins.mini-ai"),
  require("custom.plugins.treesitter"),
  require("custom.plugins.mdx"),
  require("custom.plugins.autosave"),
  require("custom.plugins.vim-tmux-navigator"),
  require("custom.plugins.comment"),
  require("custom.plugins.guess-indent"),
  require("custom.plugins.mini-splitjoin"),
  require("custom.plugins.mini-move"),
  require("custom.plugins.coerce"),
  require("custom.plugins.numb"),
  require("custom.plugins.various-textobjs"),
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
  require("custom.plugins.which-key")
)
