return {
  {
    "SmiteshP/nvim-navbuddy",
    dependencies = {
      "neovim/nvim-lspconfig",
      "SmiteshP/nvim-navic",
      "MunifTanjim/nui.nvim",
    },
    keys = {
      {
        "<leader>n",
        function()
          require("nvim-navbuddy").open()
        end,
        desc = "Open Navbuddy",
      },
    },
    config = function()
      local navbuddy = require("nvim-navbuddy")
      navbuddy.setup({
        window = {
          border = "rounded",
          size = "60%",
          position = "50%",
          sections = {
            right = {
              preview = "always",
            },
          },
        },
        use_default_mappings = true,
        lsp = {
          auto_attach = true,
        },
      })
    end,
  },
}

