return {

  -- change some telescope options
  {
    "nvim-telescope/telescope.nvim",
    lazy = false,
    keys = {
      { "<leader><space>", "<cmd>:lua require('telescope').extensions.frecency.frecency({ workspace = 'CWD' })<cr>", desc = "Find file" },
    },
    opts = {
      defaults = {
        layout_strategy = "horizontal",
        layout_config = { prompt_position = "top" },
        sorting_strategy = "ascending",
        winblend = 0,
      },
    },

    config = function(_, opts)
      local telescope = require('telescope')
      telescope.setup(opts)
      telescope.load_extension("frecency")
      telescope.load_extension("fzf")

    end,

    dependencies = {
      {
        "nvim-telescope/telescope-fzf-native.nvim",
        build = "make",
      },
      {
        "nvim-telescope/telescope-frecency.nvim",
        dependencies = {
          "kkharji/sqlite.lua",
          "nvim-tree/nvim-web-devicons"
        }
      }
    },
  },
}
