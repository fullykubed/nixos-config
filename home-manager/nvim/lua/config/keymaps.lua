-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- LazyVim sets some default window keybindings that we want to remove
-- to allow our window swicher to work
vim.keymap.del('n', '<leader>ww')
vim.keymap.del('n', '<leader>w|')
vim.keymap.del('n', '<leader>w-')
vim.keymap.del('n', '<leader>wd')

-- change save to save all open buffers and return to normal mode
vim.keymap.del({"n", "v", "i"}, "<C-s>")
vim.keymap.set({"n", "v", "i"}, "<C-s>", "<cmd>wa<cr><Esc>", {silent = true, nowait = true})



