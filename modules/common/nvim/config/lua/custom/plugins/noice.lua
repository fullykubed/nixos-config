return {
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    dependencies = {
      "MunifTanjim/nui.nvim",
      "rcarriga/nvim-notify",
    },
    opts = {
      lsp = {
        -- override markdown rendering so that **cmp** and other plugins use **Treesitter**
        override = {
          ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
          ["vim.lsp.util.stylize_markdown"] = true,
          ["cmp.entry.get_documentation"] = true,
        },
      },
      presets = {
        bottom_search = true, -- use a classic bottom cmdline for search
        command_palette = true, -- position the cmdline and popupmenu together
        long_message_to_split = true, -- long messages will be sent to a split
        inc_rename = false, -- enables an input dialog for inc-rename.nvim
        lsp_doc_border = false, -- add a border to hover docs and signature help
      },
      routes = {
        -- Skip "written" messages (from :write command)
        {
          filter = {
            event = "msg_show",
            kind = "",
            find = "written",
          },
          opts = { skip = true },
        },
        -- Skip autosave messages
        {
          filter = {
            event = "msg_show",
            kind = "",
            find = "AutoSave",
          },
          opts = { skip = true },
        },
        {
          filter = {
            event = "msg_show",
            kind = "",
            find = "saved at",
          },
          opts = { skip = true },
        },
        -- Skip vim.notify autosave notifications
        {
          filter = {
            event = "notify",
            find = "AutoSave",
          },
          opts = { skip = true },
        },
        {
          filter = {
            event = "notify",
            find = "saved at",
          },
          opts = { skip = true },
        },
      },
    },
  },
}
