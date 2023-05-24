return {
  -- Allows user to easily move windows around
  {
    "sindrets/winshift.nvim"
  },

  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      plugins = {
        spelling = true,
        presets = {
          windows = false
        }
      }
    },
    config = function(_, opts)
      local wk = require("which-key")
      wk.setup(opts)
      local keymaps = {
        mode = { "n", "v" },
        ["g"] = { name = "+goto" },
        ["gz"] = { name = "+surround" },
        ["]"] = { name = "+next" },
        ["["] = { name = "+prev" },
        ["<leader><tab>"] = { name = "+tabs" },
        ["<leader>b"] = { name = "+buffer" },
        ["<leader>c"] = { name = "+code" },
        ["<leader>f"] = { name = "+file/find" },
        ["<leader>g"] = { name = "+git" },
        ["<leader>gh"] = { name = "+hunks" },
        ["<leader>q"] = { name = "+quit/session" },
        ["<leader>s"] = { name = "+search" },
        ["<leader>u"] = { name = "+ui" },
        ["<leader>x"] = { name = "+diagnostics/quickfix" },
      }
      wk.register(keymaps)
    end,
  },

  -- Allows user to easily focus a windows
  {
    "yorickpeterse/nvim-window",
    url = "https://gitlab.com/yorickpeterse/nvim-window.git",
    keys = {
      {"<leader>w", "<cmd>:lua require('nvim-window').pick()<cr>", desc = "Focus Window", remap = true, nowait = true}
    },
    opts = {
      text =  2
    },
    config = function( ) 
      require('nvim-window').setup {}
    end
  }
}
