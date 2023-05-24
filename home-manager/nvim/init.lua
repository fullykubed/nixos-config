-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

vim.api.nvim_set_keymap("n", "<C-t>", ":Neotree<CR>", {noremap = false, silent = true})

-- don't resize windows on closing / opening
vim.o.equalalways = false

-- preserve session options
vim.o.sessionoptions="blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"

-- set the sqlite shared object path
vim.g.sqlite_clib_path = os.getenv("SQLITE_SO_PATH");

-- Start terminal mode when terminal buffer open.
vim.api.nvim_create_autocmd("TermOpen", {
  callback = function()
    vim.cmd "startinsert!"
  end,
})

vim.api.nvim_create_autocmd({ 'BufWinEnter', 'WinEnter' }, {
  callback = function()
    -- start insert mode when moving to a terminal window
    if vim.bo.buftype == 'terminal' then vim.cmd('startinsert') end
    
    -- start normal mode when moving to neo-tree
    if vim.bo.filetype == 'neo-tree' then vim.api.nvim_input('<Esc>') end
  end,
  group = m
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
  group = vim_term
})
