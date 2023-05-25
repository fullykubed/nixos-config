-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

-----------------------------------------------------------------
-- Settings for styling the window depending on the buffer type
-----------------------------------------------------------------
local windowSettingsGroup = vim.api.nvim_create_augroup("WindowSettings", {clear = true})
vim.api.nvim_create_autocmd({'WinEnter', 'BufWinEnter', 'TermOpen'}, {
  callback = function()
    if vim.bo.buftype == 'terminal' then
      vim.wo.relativenumber = false
      vim.wo.number = false
    else
      vim.wo.number = true
      vim.wo.relativenumber = true
    end
  end,
  group = windowSettingsGroup
})
-----------------------------------------------------------------
-- Ensure that the proper mode is set when working with terminals
-----------------------------------------------------------------
local terminalInsertGroup = vim.api.nvim_create_augroup("TerminalInsert", {clear = true})

vim.api.nvim_create_autocmd({ 'BufWinEnter', 'WinEnter', 'TermOpen' }, {
  callback = function()
    -- start insert mode when moving to a terminal window
    if vim.bo.buftype == 'terminal' then vim.cmd('startinsert') end
    
    -- start normal mode when moving to neo-tree
    if vim.bo.filetype == 'neo-tree' then vim.api.nvim_input('<Esc>') end
  end,
  group = terminalInsertGroup
})

-- prevents insert mode when the terminal process has exited
vim.api.nvim_create_autocmd('TermClose', {
  callback = function(ctx)
    vim.cmd('stopinsert')
    vim.api.nvim_create_autocmd('TermEnter', {
      command = 'stopinsert',
      buffer = ctx.buf,
    })
  end,
  nested = true,
  group = terminalInsertGroup
})
