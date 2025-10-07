return {
  "echasnovski/mini.move",
  version = false,
  config = function()
    require("mini.move").setup({
      mappings = {
        left = "<C-Left>",
        right = "<C-Right>",
        down = "<C-Down>",
        up = "<C-Up>",

        line_left = "<C-Left>",
        line_right = "<C-Right>",
        line_down = "<C-Down>",
        line_up = "<C-Up>",
      },

      options = {
        reindent_linewise = true,
      },
    })
  end,
  keys = {
    { "<C-Left>", desc = "Move left", mode = { "n", "v" } },
    { "<C-Down>", desc = "Move down", mode = { "n", "v" } },
    { "<C-Up>", desc = "Move up", mode = { "n", "v" } },
    { "<C-Right>", desc = "Move right", mode = { "n", "v" } },
  },
}

