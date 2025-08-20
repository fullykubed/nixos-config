return {
  -- Use fwatch.nvim for efficient file watching with inotify/FSEvents/etc
  {
    "rktjmp/fwatch.nvim",
    config = function()
      -- Enable autoread so Neovim reloads files automatically
      vim.o.autoread = true

      local fwatch = require("fwatch")
      local group = vim.api.nvim_create_augroup("auto-reload", { clear = true })

      -- Table to track watchers per buffer
      local watchers = {}

      -- Start watching a buffer's file
      local function watch_buffer(bufnr)
        local filepath = vim.api.nvim_buf_get_name(bufnr)

        -- Only watch real files, skip if already watching
        if filepath == "" or vim.bo[bufnr].buftype ~= "" or watchers[bufnr] then
          return
        end

        -- Create watcher for this file
        local watcher = fwatch.watch(filepath, {
          on_event = vim.schedule_wrap(function()
            -- Check if buffer is still valid
            if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_is_loaded(bufnr) then
              -- Only reload if not in command mode
              if vim.fn.mode() ~= "c" and vim.fn.getcmdwintype() == "" then
                vim.cmd("silent! checktime " .. bufnr)
              end
            else
              -- Stop watching invalid buffer
              if watchers[bufnr] then
                watchers[bufnr]:close()
                watchers[bufnr] = nil
              end
            end
          end),
        })

        if watcher then
          watchers[bufnr] = watcher
        end
      end

      -- Stop watching a buffer's file
      local function unwatch_buffer(bufnr)
        if watchers[bufnr] then
          watchers[bufnr]:close()
          watchers[bufnr] = nil
        end
      end

      -- Set up autocommands
      vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
        group = group,
        callback = function(args)
          watch_buffer(args.buf)
        end,
        desc = "Start watching file when buffer is loaded",
      })

      vim.api.nvim_create_autocmd("BufDelete", {
        group = group,
        callback = function(args)
          unwatch_buffer(args.buf)
        end,
        desc = "Stop watching file when buffer is deleted",
      })

      -- Additional safety checks on focus/terminal events
      vim.api.nvim_create_autocmd({ "FocusGained", "TermLeave" }, {
        group = group,
        callback = function()
          if vim.fn.mode() ~= "c" and vim.fn.getcmdwintype() == "" then
            vim.cmd("silent! checktime")
          end
        end,
        desc = "Check all files on focus/terminal events",
      })

      -- Notify when files are reloaded
      vim.api.nvim_create_autocmd("FileChangedShellPost", {
        group = group,
        callback = function()
          vim.notify("File changed on disk. Buffer reloaded!", vim.log.levels.INFO, { title = "File Reloaded" })
        end,
        desc = "Notify on file reload",
      })

      -- Auto-handle file change prompts
      vim.api.nvim_create_autocmd("FileChangedShell", {
        group = group,
        callback = function()
          vim.cmd("silent! checktime")
        end,
        desc = "Auto-handle file change warnings",
      })
    end,
  },
}