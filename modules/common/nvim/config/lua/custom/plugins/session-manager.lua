return {
  "Shatur/neovim-session-manager",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  config = function()
    local Path = require("plenary.path")
    local config = require("session_manager.config")
    require("session_manager").setup({
      sessions_dir = Path:new(vim.fn.stdpath("data"), "sessions"), -- The directory where the session files will be saved.
      autoload_mode = {
        config.AutoloadMode.GitSession,
        config.AutoloadMode.CurrentDir,
        config.AutoloadMode.LastSession,
      }, -- Try git session first, then current dir, then last session
      autosave_last_session = true, -- Automatically save last session on exit and on session switch.
      autosave_ignore_not_normal = true, -- Plugin will not save a session when no buffers are opened, or all of them aren't writable or listed.
      autosave_ignore_dirs = {}, -- A list of directories where the session will not be autosaved.
      autosave_ignore_filetypes = { -- All buffers of these file types will be closed before the session is saved.
        "gitcommit",
        "gitrebase",
      },
      autosave_ignore_buftypes = {}, -- All buffers of these bufer types will be closed before the session is saved.
      autosave_only_in_session = false, -- Always autosaves session. If true, only autosaves after a session is active.
      max_path_length = 80, -- Shorten the display path if length exceeds this threshold. Use 0 if don't want to shorten the path at all.
    })

    -- Auto save session
    vim.api.nvim_create_autocmd({ "BufWritePre" }, {
      callback = function()
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
          -- Don't save while there's any unsaved buffer
          if vim.api.nvim_get_option_value("modified", { buf = buf }) then
            return
          end
        end
        require("session_manager").save_current_session()
      end,
    })

    -- Restore Neo-tree after loading session
    vim.api.nvim_create_autocmd("User", {
      pattern = "SessionLoadPost",
      callback = function()
        -- Small delay to ensure session is fully loaded
        vim.defer_fn(function()
          -- Check if any buffer is a real file
          local has_file = false
          for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted then
              local name = vim.api.nvim_buf_get_name(buf)
              if name ~= "" and vim.fn.filereadable(name) == 1 then
                has_file = true
                break
              end
            end
          end
          
          -- If we have files loaded, show Neo-tree
          if has_file then
            vim.cmd("Neotree filesystem reveal left")
          end
        end, 100)
      end,
    })

    -- Keymaps
    vim.keymap.set("n", "<leader>so", "<cmd>SessionManager load_session<cr>", { desc = "[S]ession [O]pen" })
    vim.keymap.set("n", "<leader>ss", "<cmd>SessionManager save_current_session<cr>", { desc = "[S]ession [S]ave" })
    vim.keymap.set("n", "<leader>sl", "<cmd>SessionManager load_last_session<cr>", { desc = "[S]ession [L]oad last" })
    vim.keymap.set("n", "<leader>sd", "<cmd>SessionManager delete_session<cr>", { desc = "[S]ession [D]elete" })
  end,
}

