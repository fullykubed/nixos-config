-- Colorscheme configuration
return {
  "echasnovski/mini.hues",
  priority = 1000, -- Make sure to load this before all the other start plugins.
  config = function()
    -- Load the minispring colorscheme (blooming spring palette with green background)
    -- Other available options: miniwinter (azure), minisummer (brown/yellow), miniautumn (purple)
    vim.cmd.colorscheme("minicyan")

    -- Make comments italic
    vim.cmd([[highlight Comment cterm=italic gui=italic]])

    -- Store the colorscheme's default background
    vim.cmd([[highlight NormalDefault guibg=NONE ctermbg=NONE]])
    -- Inactive windows within Neovim get a lighter gray background
    vim.cmd([[highlight NormalNC guibg=#2a2a2a ctermbg=235]])
    -- Active window gets pure black background
    vim.cmd([[highlight NormalActive guibg=#000000 ctermbg=0]])

    -- Set initial state
    vim.cmd([[highlight! link Normal NormalActive]])

    -- Make line number backgrounds transparent (inherit from Normal)
    vim.cmd([[highlight LineNr guibg=NONE ctermbg=NONE]])
    vim.cmd([[highlight CursorLineNr guibg=NONE ctermbg=NONE]])
    vim.cmd([[highlight SignColumn guibg=NONE ctermbg=NONE]])
    vim.cmd([[highlight CursorLineSign guibg=NONE ctermbg=NONE]])

    -- Git signs colors with background highlights for better visibility
    vim.cmd([[highlight GitSignsAdd guifg=#00ff00 guibg=#003300 ctermfg=green ctermbg=darkgreen]])
    vim.cmd([[highlight GitSignsChange guifg=#ffff00 guibg=#333300 ctermfg=yellow ctermbg=darkyellow]])
    vim.cmd([[highlight GitSignsDelete guifg=#ff0000 guibg=#330000 ctermfg=red ctermbg=darkred]])
    vim.cmd([[highlight GitSignsTopdelete guifg=#ff0000 guibg=#330000 ctermfg=red ctermbg=darkred]])
    vim.cmd([[highlight GitSignsChangedelete guifg=#ff8800 guibg=#331100 ctermfg=yellow ctermbg=darkyellow]])
    vim.cmd([[highlight GitSignsUntracked guifg=#808080 guibg=#1a1a1a ctermfg=gray ctermbg=darkgray]])

    -- Diagnostic signs colors (errors, warnings, info, hints)
    vim.cmd([[highlight DiagnosticSignError guifg=#ff9999 guibg=#3d2626 gui=bold]])
    vim.cmd([[highlight DiagnosticSignWarn guifg=#ffcc99 guibg=#3d3326 gui=bold]])
    vim.cmd([[highlight DiagnosticSignInfo guifg=#87ceeb guibg=#1e3a4a gui=bold]])
    vim.cmd([[highlight DiagnosticSignHint guifg=#add8e6 guibg=#1e3a4a gui=bold]])

    -- Diagnostic text/underline colors
    vim.cmd([[highlight DiagnosticError guifg=#ff9999]])
    vim.cmd([[highlight DiagnosticWarn guifg=#ffcc99]])
    vim.cmd([[highlight DiagnosticInfo guifg=#87ceeb]])
    vim.cmd([[highlight DiagnosticHint guifg=#add8e6]])

    -- Diagnostic underlines
    vim.cmd([[highlight DiagnosticUnderlineError gui=undercurl guisp=#ff9999]])
    vim.cmd([[highlight DiagnosticUnderlineWarn gui=undercurl guisp=#ffcc99]])
    vim.cmd([[highlight DiagnosticUnderlineInfo gui=undercurl guisp=#87ceeb]])
    vim.cmd([[highlight DiagnosticUnderlineHint gui=undercurl guisp=#add8e6]])

    -- Diagnostic virtual text
    vim.cmd([[highlight DiagnosticVirtualTextError guifg=#ff9999 gui=bold]])
    vim.cmd([[highlight DiagnosticVirtualTextWarn guifg=#ffcc99]])
    vim.cmd([[highlight DiagnosticVirtualTextInfo guifg=#87ceeb]])
    vim.cmd([[highlight DiagnosticVirtualTextHint guifg=#add8e6]])

    -- Create autocommands for window switching within Neovim
    vim.api.nvim_create_autocmd({ "WinEnter", "BufEnter" }, {
      callback = function()
        -- Set current window to black background
        vim.wo.winhighlight = "Normal:NormalActive,NormalNC:NormalNC"
      end,
    })

    -- When Neovim regains focus, restore the active buffer styling
    vim.api.nvim_create_autocmd("FocusGained", {
      callback = function()
        vim.cmd([[highlight! link Normal NormalActive]])
        -- Restore window highlighting for all windows
        for _, win in ipairs(vim.api.nvim_list_wins()) do
          vim.api.nvim_win_set_option(win, "winhighlight", "Normal:NormalActive,NormalNC:NormalNC")
        end
      end,
    })

    -- When Neovim loses focus, match tmux's inactive pane color
    vim.api.nvim_create_autocmd("FocusLost", {
      callback = function()
        -- Set all windows to match tmux's inactive pane background
        vim.cmd([[highlight! Normal guibg=#2a2a2a ctermbg=235]])
        vim.cmd([[highlight! NormalNC guibg=#2a2a2a ctermbg=235]])
        -- Clear window-specific highlighting so all windows use the same color
        for _, win in ipairs(vim.api.nvim_list_wins()) do
          vim.api.nvim_win_set_option(win, "winhighlight", "")
        end
      end,
    })
  end,
}