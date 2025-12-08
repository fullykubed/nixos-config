return {
  "0x00-ketsu/autosave.nvim",
  event = { "InsertLeave", "TextChanged" },
  opts = {
    enabled = true,
    execution_message = {
      enabled = false,
      message = function()
        return "AutoSaved at " .. vim.fn.strftime("%H:%M:%S")
      end,
      dim = 0.18,
      cleaning_interval = 1250,
    },
    trigger_events = {
      immediate_save = { "BufLeave", "FocusLost" },
      defer_save = { "InsertLeave", "TextChanged" },
      cancel_defered_save = { "InsertEnter" },
    },
    condition = function(buf)
      local fn = vim.fn
      local utils = require("autosave.utils.data")

      if fn.getbufvar(buf, "&modifiable") == 1 and utils.not_in(fn.getbufvar(buf, "&filetype"), { "gitcommit" }) then
        return true
      end
      return false
    end,
    write_all_buffers = false,
    debounce_delay = 135,
    callbacks = {
      before_saving = function() end,
      after_saving = function() end,
    },
  },
}
