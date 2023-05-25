-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

vim.api.nvim_set_keymap("n", "<C-t>", ":Neotree<CR>", {noremap = false, silent = true})

-- don't resize windows on closing / opening
vim.o.equalalways = false

-- preserve session options
vim.o.sessionoptions="blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"

-- set the sqlite shared object path
vim.g.sqlite_clib_path = os.getenv("SQLITE_SO_PATH");


