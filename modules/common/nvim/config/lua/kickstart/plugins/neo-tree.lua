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
    window = {
      mappings = {
        ["\\"] = "close_window",
      },
    },
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
      -- Always show hidden files
      filtered_items = {
        visible = true, -- Show hidden files by default
        hide_dotfiles = false,
        hide_gitignored = false,
        hide_hidden = false, -- for Windows
      },
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
    -- Disable auto-centering in Neo-tree
    event_handlers = {
      {
        event = "neo_tree_buffer_enter",
        handler = function()
          vim.opt_local.scrolloff = 0
          vim.opt_local.sidescrolloff = 0
        end,
      },
    },
  },
  config = function(_, opts)
    -- Set up Neo-tree with options
    require("neo-tree").setup(opts)

    -- Helper function to find git directory (handles worktrees)
    local function get_git_dir()
      local cwd = vim.fn.getcwd()
      local git_path = vim.fs.find('.git', { path = cwd, upward = true })[1]

      if not git_path then
        return nil
      end

      local stat = vim.uv.fs_stat(git_path)
      if not stat then
        return nil
      end

      if stat.type == 'file' then
        -- It's a worktree, read the file to get actual git dir
        local file = io.open(git_path, 'r')
        if file then
          local content = file:read('*a')
          file:close()
          -- Content format: 'gitdir: /actual/path/to/.git/worktrees/name'
          local gitdir = content:match('gitdir:%s*(.+)')
          if gitdir then
            return vim.trim(gitdir)
          end
        end
      else
        return git_path
      end

      return nil
    end

    -- Helper to refresh Neo-tree git status
    local function refresh_neotree_git()
      if package.loaded["neo-tree.sources.git_status"] then
        require("neo-tree.sources.git_status").refresh()
      end
    end

    -- Set up git index watcher
    local git_index_watcher = nil

    local function setup_git_index_watcher()
      local git_dir = get_git_dir()
      if not git_dir then
        return
      end

      local index_path = git_dir .. '/index'

      -- Check if index file exists
      if not vim.uv.fs_stat(index_path) then
        return
      end

      git_index_watcher = vim.uv.new_fs_poll()
      git_index_watcher:start(index_path, 1000, function(err)
        if not err then
          vim.schedule(function()
            refresh_neotree_git()
          end)
        end
      end)
    end

    -- Clean up watcher on exit
    vim.api.nvim_create_autocmd("VimLeavePre", {
      callback = function()
        if git_index_watcher then
          git_index_watcher:stop()
          git_index_watcher = nil
        end
      end,
    })

    -- Start watcher after Neo-tree loads
    setup_git_index_watcher()

    -- Set up FocusGained autocmd to refresh git status
    local focus_group = vim.api.nvim_create_augroup("neotree-git-refresh", { clear = true })

    vim.api.nvim_create_autocmd("FocusGained", {
      group = focus_group,
      callback = function()
        if package.loaded["neo-tree.sources.git_status"] then
          require("neo-tree.sources.git_status").refresh()
        end
      end,
      desc = "Refresh Neo-tree git status on focus",
    })

    -- Refresh on terminal close (lazygit)
    vim.api.nvim_create_autocmd("TermClose", {
      group = focus_group,
      pattern = "*lazygit*",
      callback = function()
        if package.loaded["neo-tree.sources.git_status"] then
          require("neo-tree.sources.git_status").refresh()
        end
      end,
      desc = "Refresh Neo-tree git status after lazygit closes",
    })
  end,
}
