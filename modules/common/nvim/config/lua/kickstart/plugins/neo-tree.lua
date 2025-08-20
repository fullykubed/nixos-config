-- Neo-tree is a Neovim plugin to browse the file system
-- https://github.com/nvim-neo-tree/neo-tree.nvim

return {
  "nvim-neo-tree/neo-tree.nvim",
  version = "*",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons", -- not strictly required, but recommended
    "MunifTanjim/nui.nvim",
  },
  lazy = false,
  keys = {
    { "\\", ":Neotree reveal<CR>", desc = "NeoTree reveal", silent = true },
  },
  opts = {
    filesystem = {
      follow_current_file = {
        enabled = true,
        leave_dirs_open = false,
      },
      window = {
        mappings = {
          ["\\"] = "close_window",
        },
      },
      -- Auto refresh when files change
      use_libuv_file_watcher = true,
      scan_mode = "deep",
    },
    git_status = {
      window = {
        mappings = {
          ["\\"] = "close_window",
        },
      },
    },
    -- Enable git status tracking
    enable_git_status = true,
    enable_diagnostics = true,
    -- Refresh neo-tree when git status changes
    event_handlers = {
      {
        event = "file_opened",
        handler = function()
          require("neo-tree.sources.filesystem").reset_search()
        end,
      },
      {
        event = "git_event",
        handler = function(args)
          if args.refresh then
            require("neo-tree.sources.manager").refresh("filesystem")
          end
        end,
      },
    },
  },
}
