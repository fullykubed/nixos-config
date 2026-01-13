return {
  "m00qek/baleia.nvim",
  version = "*",
  config = function()
    vim.g.baleia = require("baleia").setup({
      strip_ansi_codes = true,
      async = true,
    })

    -- Command to colorize current buffer
    vim.api.nvim_create_user_command("BaleiaColorize", function()
      vim.g.baleia.once(vim.api.nvim_get_current_buf())
    end, { bang = true })

    -- Command to show baleia logs
    vim.api.nvim_create_user_command("BaleiaLogs", vim.g.baleia.logger.show, { bang = true })

    -- Automatically colorize terminal output, man pages, and log files
    vim.api.nvim_create_autocmd({ "BufReadPost", "BufWinEnter" }, {
      pattern = { "*.log", "man://*" },
      callback = function()
        vim.g.baleia.automatically(vim.api.nvim_get_current_buf())
      end,
    })

    -- Colorize stdin input (when nvim is used as a pager)
    vim.api.nvim_create_autocmd({ "StdinReadPost" }, {
      callback = function()
        local buf = vim.api.nvim_get_current_buf()
        -- Set as scratch buffer so it won't prompt to save
        vim.bo[buf].buftype = "nofile"
        vim.bo[buf].bufhidden = "wipe"
        vim.bo[buf].swapfile = false
        vim.g.baleia.once(buf)
        -- Mark as not modified after a short delay (baleia is async)
        vim.defer_fn(function()
          vim.bo[buf].modified = false
        end, 100)
      end,
    })

    -- Colorize quickfix windows
    vim.api.nvim_create_autocmd({ "BufReadPost" }, {
      pattern = "quickfix",
      callback = function()
        local buf = vim.api.nvim_get_current_buf()
        vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
        vim.g.baleia.automatically(buf)
        vim.api.nvim_set_option_value("modified", false, { buf = buf })
        vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
      end,
    })
  end,
}
