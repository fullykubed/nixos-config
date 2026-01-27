-- Adds git related signs to the gutter, as well as utilities for managing changes
-- NOTE: gitsigns is already included in init.lua but contains only the base
-- config. This will add also the recommended keymaps.

-- Helper to show commit in floating window with delta
local function show_commit_float(commit_hash)
  if not commit_hash or commit_hash == "" then
    return
  end

  -- Create floating window
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
  })

  -- Run git show with delta in terminal
  vim.fn.termopen("git show " .. commit_hash .. " | delta --paging=never --line-numbers --hyperlinks", {
    on_exit = function()
      vim.bo[buf].modifiable = false
    end,
  })

  -- Switch to normal mode for scrolling with j/k
  vim.cmd("stopinsert")

  -- Map q and Esc to close
  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf, nowait = true })
  vim.keymap.set("n", "<Esc>", function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf, nowait = true })
end

return {
  {
    "lewis6991/gitsigns.nvim",
    opts = {
      signs = {
        add = { text = "+" },
        change = { text = "~" },
        delete = { text = "_" },
        topdelete = { text = "‾" },
        changedelete = { text = "~" },
        untracked = { text = "┆" },
      },
      signs_staged = {
        add = { text = "+" },
        change = { text = "~" },
        delete = { text = "_" },
        topdelete = { text = "‾" },
        changedelete = { text = "~" },
      },
      signcolumn = true, -- Toggle with `:Gitsigns toggle_signs`
      numhl = false, -- Toggle with `:Gitsigns toggle_numhl`
      linehl = false, -- Toggle with `:Gitsigns toggle_linehl`
      word_diff = false, -- Toggle with `:Gitsigns toggle_word_diff`
      on_attach = function(bufnr)
        local gitsigns = require("gitsigns")

        local function map(mode, l, r, opts)
          opts = opts or {}
          opts.buffer = bufnr
          vim.keymap.set(mode, l, r, opts)
        end

        -- Helper function to refresh Neo-tree git status
        local function refresh_neotree_git()
          vim.schedule(function()
            if package.loaded["neo-tree.sources.git_status"] then
              require("neo-tree.sources.git_status").refresh()
            end
          end)
        end

        -- Navigation
        map("n", "]c", function()
          if vim.wo.diff then
            vim.cmd.normal({ "]c", bang = true })
          else
            ---@diagnostic disable-next-line: param-type-mismatch
            gitsigns.nav_hunk("next")
          end
        end, { desc = "Jump to next git [c]hange" })

        map("n", "[c", function()
          if vim.wo.diff then
            vim.cmd.normal({ "[c", bang = true })
          else
            ---@diagnostic disable-next-line: param-type-mismatch
            gitsigns.nav_hunk("prev")
          end
        end, { desc = "Jump to previous git [c]hange" })

        -- Actions
        -- visual mode
        map("v", "<leader>gs", function()
          gitsigns.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
          refresh_neotree_git()
        end, { desc = "Git [s]tage hunk" })
        map("v", "<leader>gr", function()
          gitsigns.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
          refresh_neotree_git()
        end, { desc = "Git [r]eset hunk" })
        -- normal mode
        map("n", "<leader>gs", function()
          gitsigns.stage_hunk()
          refresh_neotree_git()
        end, { desc = "Git [s]tage hunk" })
        map("n", "<leader>gr", function()
          gitsigns.reset_hunk()
          refresh_neotree_git()
        end, { desc = "Git [r]eset hunk" })
        map("n", "<leader>gS", function()
          gitsigns.stage_buffer()
          refresh_neotree_git()
        end, { desc = "Git [S]tage buffer" })
        map("n", "<leader>gu", gitsigns.stage_hunk, { desc = "Git [u]ndo stage hunk" })
        map("n", "<leader>gR", function()
          gitsigns.reset_buffer()
          refresh_neotree_git()
        end, { desc = "Git [R]eset buffer" })
        map("n", "<leader>gp", gitsigns.preview_hunk, { desc = "Git [p]review hunk" })
        map("n", "<leader>gb", function()
          gitsigns.blame_line({ full = true })
        end, { desc = "Git [b]lame line (full)" })
        map("n", "<leader>gd", gitsigns.diffthis, { desc = "Git [d]iff against index" })
        map("n", "<leader>gD", function()
          ---@diagnostic disable-next-line: param-type-mismatch
          gitsigns.diffthis("@")
        end, { desc = "Git [D]iff against last commit" })
        -- Toggles
        map("n", "<leader>tb", gitsigns.toggle_current_line_blame, { desc = "[T]oggle git show [b]lame line" })
        map("n", "<leader>tD", gitsigns.preview_hunk_inline, { desc = "[T]oggle git show [D]eleted" })
        map("n", "<leader>gB", function()
          -- Check if blame buffer exists and is visible
          for _, win in ipairs(vim.api.nvim_list_wins()) do
            local buf = vim.api.nvim_win_get_buf(win)
            local ft = vim.bo[buf].filetype
            if ft == "gitsigns-blame" then
              vim.api.nvim_win_close(win, true)
              return
            end
          end
          gitsigns.blame()
        end, { desc = "Git [B]lame buffer (toggle)" })

        -- Override Enter in blame buffer to show commit with delta in floating window
        vim.api.nvim_create_autocmd("FileType", {
          pattern = "gitsigns-blame",
          callback = function()
            vim.schedule(function()
              -- Close blame buffer with Escape
              vim.keymap.set("n", "<Esc>", function()
                vim.api.nvim_win_close(0, true)
              end, { buffer = true, nowait = true, desc = "Close blame buffer" })

              -- Helper to find commit hash, searching upward if needed
              local function find_commit_hash()
                local lnum = vim.fn.line(".")
                while lnum >= 1 do
                  local line = vim.fn.getline(lnum)
                  local hash = line:match("[┍┕│]%s*(%x%x%x%x%x%x%x%x)")
                  if hash then
                    return hash
                  end
                  lnum = lnum - 1
                end
                return nil
              end

              vim.keymap.set("n", "<CR>", function()
                local hash = find_commit_hash()
                if hash then
                  -- Open lazygit in floating window and search for commit
                  local width = math.floor(vim.o.columns * 0.9)
                  local height = math.floor(vim.o.lines * 0.9)
                  local row = math.floor((vim.o.lines - height) / 2)
                  local col = math.floor((vim.o.columns - width) / 2)

                  local buf = vim.api.nvim_create_buf(false, true)
                  local win = vim.api.nvim_open_win(buf, true, {
                    relative = "editor",
                    width = width,
                    height = height,
                    row = row,
                    col = col,
                    style = "minimal",
                    border = "rounded",
                  })

                  local term_id = vim.fn.termopen("lazygit", {
                    on_exit = function()
                      if vim.api.nvim_win_is_valid(win) then
                        vim.api.nvim_win_close(win, true)
                      end
                    end,
                  })
                  vim.cmd("startinsert")
                  -- Switch to commits panel (4), search, then press escape to close search
                  vim.defer_fn(function()
                    vim.api.nvim_chan_send(term_id, "4/" .. hash .. "\r\x1b")
                  end, 300)
                end
              end, { buffer = true, nowait = true, desc = "Open lazygit at commit" })
            end)
          end,
        })
      end,
    },
  },
}
