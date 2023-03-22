return {

  -- change some telescope options and a keymap to browse plugin files
  {
    "nvim-telescope/telescope.nvim", keys = { -- add a keymap to browse plugin files stylua: ignore { "<leader>fp", function() require("telescope.builtin").find_files({ cwd = require("lazy.core.config").options.root }) end, desc = "Find Plugin File", },
     { "<leader>p", function() require("telescope").extensions.project.project{ display_type = 'full'} end, desc = "Open project"}
    },
    -- change some options
    opts = {
      defaults = {
        layout_strategy = "horizontal",
        layout_config = { prompt_position = "top" },
        sorting_strategy = "ascending",
        winblend = 0,
      },
    },
  },

  -- add telescope-fzf-native
  {
    "telescope.nvim",
    dependencies = {
      "nvim-telescope/telescope-fzf-native.nvim",
      "nvim-telescope/telescope-project.nvim",
      build = "make",
      config = function()
        require("telescope").setup {
          extensions = {
            project = {
              base_dirs = {
                {path = "~/repos/", max_depth = 4 },
              }
            },
            hidden_files = true,
            sync_with_nvim_tree = true,
          }
        }
        require("telescope").load_extension("fzf")
        require("telescope").load_extension("project")
      end,
    },
  },
}
