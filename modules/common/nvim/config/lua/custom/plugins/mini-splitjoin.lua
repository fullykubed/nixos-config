return {
  "echasnovski/mini.splitjoin",
  version = false, -- Use latest version
  config = function()
    require("mini.splitjoin").setup({
      -- Module mappings. Use `''` (empty string) to disable one.
      mappings = {
        toggle = "gS", -- Toggle between split and join
        split = "",    -- Disabled in favor of toggle
        join = "",     -- Disabled in favor of toggle
      },

      -- Detection options
      detect = {
        -- Array of Lua patterns to detect region boundaries
        brackets = nil, -- Use default
        -- Array of quotes to detect strings
        quotes = nil,   -- Use default
        -- Array of separator patterns
        separator = ",",
      },

      -- Split options
      split = {
        hooks_pre = {},
        hooks_post = {},
      },

      -- Join options
      join = {
        hooks_pre = {},
        hooks_post = {},
      },
    })
  end,
  keys = {
    { "gS", desc = "Toggle split/join" },
  },
}