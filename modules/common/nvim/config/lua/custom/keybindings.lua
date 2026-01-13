-- Custom keybindings for Neovim
-- This file contains all keymaps for Neovim configuration

-------------------------------------------------------------------
-- Basic Keymaps from Kickstart
-------------------------------------------------------------------

-- Clear highlights on search when pressing <Esc> in normal mode
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

-- Diagnostic keymaps
vim.keymap.set("n", "<leader>qd", vim.diagnostic.setloclist, { desc = "Open diagnostic [Q]uickfix list" })

-- Exit terminal mode
vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- Insert mode navigation with Ctrl+h/j/k/l
vim.keymap.set("i", "<C-h>", "<Left>", { desc = "Move cursor left in insert mode" })
vim.keymap.set("i", "<C-j>", "<Down>", { desc = "Move cursor down in insert mode" })
vim.keymap.set("i", "<C-k>", "<Up>", { desc = "Move cursor up in insert mode" })
vim.keymap.set("i", "<C-l>", "<Right>", { desc = "Move cursor right in insert mode" })

-- Additional useful insert mode mappings
vim.keymap.set("i", "<C-a>", "<Home>", { desc = "Go to beginning of line in insert mode" })
vim.keymap.set("i", "<C-e>", "<End>", { desc = "Go to end of line in insert mode" })
vim.keymap.set("i", "<C-w>", "<C-\\><C-o>dB", { desc = "Delete word backward in insert mode" })
vim.keymap.set("i", "<C-u>", "<C-\\><C-o>d0", { desc = "Delete to beginning of line in insert mode" })

-------------------------------------------------------------------
-- Custom Additional Keymaps
-------------------------------------------------------------------

-- Better indenting (stays in visual mode)
vim.keymap.set("v", "<", "<gv", { desc = "Indent left and reselect" })
vim.keymap.set("v", ">", ">gv", { desc = "Indent right and reselect" })

-- Move lines up/down in visual mode
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

-- Better paste (doesn't overwrite register when pasting over selection)
vim.keymap.set("x", "<leader>p", [["_dP]], { desc = "Paste without yanking deleted text" })

-- Change without yanking (uses black hole register)
vim.keymap.set({ "n", "v" }, "c", [["_c]], { desc = "Change without yanking" })
vim.keymap.set("n", "C", [["_C]], { desc = "Change to end of line without yanking" })

-- Quick save
vim.keymap.set("n", "<leader>w", "<cmd>w<CR>", { desc = "Save file" })

-- Quick quit
vim.keymap.set("n", "<leader>q", "<cmd>q<CR>", { desc = "Quit" })
vim.keymap.set("n", "<leader>Q", "<cmd>qa<CR>", { desc = "Quit all" })

-------------------------------------------------------------------
-- Buffer & Window Keymaps
-------------------------------------------------------------------

-- Buffer navigation
vim.keymap.set("n", "<S-h>", "<cmd>bprevious<CR>", { desc = "Previous buffer" })
vim.keymap.set("n", "<S-l>", "<cmd>bnext<CR>", { desc = "Next buffer" })
vim.keymap.set("n", "<leader>bd", "<cmd>bdelete<CR>", { desc = "Delete buffer" })

-- Toggle relative line numbers
vim.keymap.set("n", "<leader>tr", function()
  vim.wo.relativenumber = not vim.wo.relativenumber
end, { desc = "Toggle relative line numbers" })

-- Quick fix list navigation
vim.keymap.set("n", "]q", "<cmd>cnext<CR>", { desc = "Next quickfix item" })
vim.keymap.set("n", "[q", "<cmd>cprev<CR>", { desc = "Previous quickfix item" })

-- Location list navigation
vim.keymap.set("n", "]l", "<cmd>lnext<CR>", { desc = "Next location list item" })
vim.keymap.set("n", "[l", "<cmd>lprev<CR>", { desc = "Previous location list item" })

-- Select all
vim.keymap.set("n", "<C-a>", "gg<S-v>G", { desc = "Select all" })

-- Replace operations
vim.keymap.set(
  "n",
  "<leader>rw",
  [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]],
  { desc = "Replace word under cursor" }
)

-- Make file executable
vim.keymap.set("n", "<leader>nx", "<cmd>!chmod +x %<CR>", { desc = "Make file executable", silent = true })

-- Resize windows with arrow keys
vim.keymap.set("n", "<C-Left>", "<cmd>vertical resize -2<CR>", { desc = "Decrease window width" })
vim.keymap.set("n", "<C-Right>", "<cmd>vertical resize +2<CR>", { desc = "Increase window width" })

-------------------------------------------------------------------
-- Pager Mode Keymaps
-------------------------------------------------------------------

-- Allow q and Escape to quit when nvim is used as a pager (reading from stdin)
vim.api.nvim_create_autocmd({ "StdinReadPost" }, {
  group = vim.api.nvim_create_augroup("pager-keybindings", { clear = true }),
  callback = function()
    local buf = vim.api.nvim_get_current_buf()
    vim.keymap.set("n", "q", "<cmd>q<cr>", { buffer = buf, nowait = true, desc = "Quit pager" })
    vim.keymap.set("n", "<Esc>", "<cmd>q<cr>", { buffer = buf, nowait = true, desc = "Quit pager" })
  end,
})
