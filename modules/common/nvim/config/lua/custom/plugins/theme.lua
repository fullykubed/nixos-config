-- Theme configuration using Stylix colors with mini.base16
return {
  "echasnovski/mini.base16",
  priority = 1000,
  config = function()
    -- Smart loader: uses cache but checks file modification time
    local function load_colors()
      local colors_path = vim.fn.stdpath("config") .. "/lua/colors.lua"
      local colors_mtime = vim.fn.getftime(colors_path)

      -- Check if we have a cached version with matching mtime
      if package.loaded.colors and package.loaded.colors._mtime == colors_mtime then
        return package.loaded.colors
      end

      -- File changed or not cached - reload
      package.loaded.colors = nil
      local colors = dofile(colors_path)
      colors._mtime = colors_mtime
      package.loaded.colors = colors

      return colors
    end

    local colors = load_colors()

    -- Apply base16 theme using mini.base16 with Stylix colors
    require("mini.base16").setup({
      palette = colors,
    })

    -- Helper function to darken a hex color
    local function darken(hex, amount)
      amount = amount or 0.9 -- Default to 90% brightness
      local r = tonumber(hex:sub(2, 3), 16)
      local g = tonumber(hex:sub(4, 5), 16)
      local b = tonumber(hex:sub(6, 7), 16)
      r = math.floor(r * amount)
      g = math.floor(g * amount)
      b = math.floor(b * amount)
      return string.format("#%02x%02x%02x", r, g, b)
    end

    local darker_bg = darken(colors.base00, 0.85)

    vim.cmd([[highlight! LineNr guibg=NONE ctermbg=NONE]])
    vim.cmd([[highlight! LineNrAbove guibg=NONE ctermbg=NONE]])
    vim.cmd([[highlight! LineNrBelow guibg=NONE ctermbg=NONE]])
    vim.cmd([[highlight! CursorLineNr guibg=NONE ctermbg=NONE]])
    vim.cmd([[highlight! SignColumn guibg=NONE ctermbg=NONE]])
    vim.cmd([[highlight! SignColumnSB guibg=NONE ctermbg=NONE]])
    vim.cmd([[highlight! CursorLineSign guibg=NONE ctermbg=NONE]])
    vim.cmd([[highlight! FoldColumn guibg=NONE ctermbg=NONE]])
    vim.cmd([[highlight! StatusColumn guibg=NONE ctermbg=NONE]])

    -- Set Normal to transparent by default
    vim.cmd(string.format([[highlight! Normal guibg=%s ctermbg=NONE]], colors.base01))
    vim.cmd(string.format([[highlight! NormalNC guibg=%s ctermbg=black]], colors.base00))
    vim.cmd([[highlight! NonText guibg=NONE guifg=NONE ctermbg=NONE ctermfg=NONE]])
    vim.cmd([[highlight! EndOfBuffer guibg=NONE guifg=NONE ctermbg=NONE ctermfg=NONE]])
    -- Remove all window separator borders
    vim.cmd([[highlight! WinSeparator guibg=NONE ctermbg=NONE guifg=NONE ctermfg=NONE]])
    vim.cmd([[highlight! VertSplit guibg=NONE ctermbg=NONE guifg=NONE ctermfg=NONE]])
    vim.cmd([[highlight! FloatBorder guibg=NONE ctermbg=NONE]])
    -- Message area at bottom of buffer
    vim.cmd(string.format([[highlight! MsgArea guibg=%s ctermbg=NONE]], colors.base04))
    -- Make comments italic
    vim.cmd([[highlight! Comment cterm=italic gui=italic]])
    -- Git signs with transparent backgrounds
    vim.cmd([[highlight! GitSignsAdd guibg=NONE ctermbg=NONE]])
    vim.cmd([[highlight! GitSignsChange guibg=NONE ctermbg=NONE]])
    vim.cmd([[highlight! GitSignsDelete guibg=NONE ctermbg=NONE]])
    vim.cmd([[highlight! GitSignsTopdelete guibg=NONE ctermbg=NONE]])
    vim.cmd([[highlight! GitSignsChangedelete guibg=NONE ctermbg=NONE]])
    vim.cmd([[highlight! GitSignsUntracked guibg=NONE ctermbg=NONE]])
    -- NeoTree border with transparent background
    vim.cmd([[highlight! NeoTreeWinSeparator guibg=NONE ctermbg=NONE guifg=NONE ctermfg=NONE]])
    vim.cmd([[highlight! NeoTreeVertSplit guibg=NONE ctermbg=NONE guifg=NONE ctermfg=NONE]])
    -- Scrollbar gutter background
    vim.cmd([[highlight! ScrollbarCursor guibg=NONE ctermbg=NONE]])
    vim.cmd([[highlight! ScrollbarHandle guibg=NONE ctermbg=NONE]])
    vim.cmd([[highlight! ScrollbarSearch guibg=NONE ctermbg=NONE]])
    vim.cmd([[highlight! ScrollbarError guibg=NONE ctermbg=NONE]])
    vim.cmd([[highlight! ScrollbarWarn guibg=NONE ctermbg=NONE]])
    vim.cmd([[highlight! ScrollbarInfo guibg=NONE ctermbg=NONE]])
    vim.cmd([[highlight! ScrollbarHint guibg=NONE ctermbg=NONE]])
    vim.cmd([[highlight! ScrollbarMisc guibg=NONE ctermbg=NONE]])
    -- Notify background
    vim.cmd(string.format([[highlight! NotifyBackground guibg=%s ctermbg=NONE]], colors.base00))
    -- Treesitter context background
    vim.cmd(string.format([[highlight! TreesitterContext guibg=%s ctermbg=NONE]], colors.base00))
    vim.cmd(string.format([[highlight! TreesitterContextLineNumber guibg=%s ctermbg=NONE]], colors.base00))

    -- Initialize on startup
    vim.schedule(function()
      -- Redefine groups after mini.base16
      vim.cmd(string.format([[highlight! Normal guibg=%s ctermbg=NONE]], colors.base01))
      vim.cmd(string.format([[highlight! NormalNC guibg=%s ctermbg=black]], colors.base00))
      vim.cmd(string.format([[highlight! NotifyBackground guibg=%s ctermbg=NONE]], colors.base00))
      vim.cmd(string.format([[highlight! TreesitterContext guibg=%s ctermbg=NONE]], colors.base00))
      vim.cmd(string.format([[highlight! TreesitterContextLineNumber guibg=%s ctermbg=NONE]], colors.base00))

      -- Change comments to lighter grey
      vim.cmd(string.format([[highlight! Comment guifg=%s gui=italic cterm=italic]], colors.base0A))

      -- Change visual selection background to lighter grey
      vim.cmd(string.format([[highlight! Visual guibg=%s guifg=NONE]], colors.base03))

      -- Override ALL diagnostic-related colors (inline, signs, virtual text, Neo-tree)
      -- Base diagnostic colors
      vim.cmd(string.format([[highlight! DiagnosticError guifg=%s]], colors.base08))
      vim.cmd(string.format([[highlight! DiagnosticWarn guifg=%s]], colors.base09))
      vim.cmd(string.format([[highlight! DiagnosticInfo guifg=%s]], colors.base0C))
      vim.cmd(string.format([[highlight! DiagnosticHint guifg=%s]], colors.base0D))

      -- Sign column diagnostics
      vim.cmd(string.format([[highlight! DiagnosticSignError guifg=%s guibg=NONE]], colors.base08))
      vim.cmd(string.format([[highlight! DiagnosticSignWarn guifg=%s guibg=NONE]], colors.base09))
      vim.cmd(string.format([[highlight! DiagnosticSignInfo guifg=%s guibg=NONE]], colors.base0C))
      vim.cmd(string.format([[highlight! DiagnosticSignHint guifg=%s guibg=NONE]], colors.base0D))

      -- Virtual text diagnostics
      vim.cmd(string.format([[highlight! DiagnosticVirtualTextError guifg=%s guibg=NONE]], colors.base08))
      vim.cmd(string.format([[highlight! DiagnosticVirtualTextWarn guifg=%s guibg=NONE]], colors.base09))
      vim.cmd(string.format([[highlight! DiagnosticVirtualTextInfo guifg=%s guibg=NONE]], colors.base0C))
      vim.cmd(string.format([[highlight! DiagnosticVirtualTextHint guifg=%s guibg=NONE]], colors.base0D))

      -- Underline diagnostics
      vim.cmd(string.format([[highlight! DiagnosticUnderlineError guisp=%s gui=underline]], colors.base08))
      vim.cmd(string.format([[highlight! DiagnosticUnderlineWarn guisp=%s gui=underline]], colors.base09))
      vim.cmd(string.format([[highlight! DiagnosticUnderlineInfo guisp=%s gui=underline]], colors.base0C))
      vim.cmd(string.format([[highlight! DiagnosticUnderlineHint guisp=%s gui=underline]], colors.base0D))

      -- Neo-tree specific
      vim.cmd(string.format([[highlight! NeoTreeDiagnosticErrorIcon guifg=%s guibg=NONE]], colors.base08))
      vim.cmd(string.format([[highlight! NeoTreeDiagnosticWarnIcon guifg=%s guibg=NONE]], colors.base09))
      vim.cmd(string.format([[highlight! NeoTreeDiagnosticInfoIcon guifg=%s guibg=NONE]], colors.base0C))
      vim.cmd(string.format([[highlight! NeoTreeDiagnosticHintIcon guifg=%s guibg=NONE]], colors.base0D))

      -- Neo-tree folder names use default foreground color (keep icons blue)
      vim.cmd(string.format([[highlight! NeoTreeDirectoryName guifg=%s guibg=NONE]], colors.base05))
      vim.cmd(string.format([[highlight! NeoTreeRootName guifg=%s guibg=NONE gui=bold]], colors.base05))

      -- Treesitter field colors (change from red to cyan)
      vim.cmd(string.format([[highlight! @field guifg=%s]], colors.base0C))
      vim.cmd(string.format([[highlight! @property guifg=%s]], colors.base0C))
      vim.cmd(string.format([[highlight! @variable.member guifg=%s]], colors.base0C))

      -- Treesitter booleans and numbers to blue
      vim.cmd(string.format([[highlight! @boolean guifg=%s]], colors.base0D))
      vim.cmd(string.format([[highlight! @number guifg=%s]], colors.base0D))
      vim.cmd(string.format([[highlight! @number.float guifg=%s]], colors.base0D))

      -- TSX/JSX/Astro tag and attribute colors
      -- React components and HTML elements (blue)
      vim.cmd(string.format([[highlight! @tag.tsx guifg=%s]], colors.base0D))
      vim.cmd(string.format([[highlight! @tag.jsx guifg=%s]], colors.base0D))
      vim.cmd(string.format([[highlight! @tag.builtin.tsx guifg=%s]], colors.base0D))
      vim.cmd(string.format([[highlight! @tag.builtin.jsx guifg=%s]], colors.base0D))

      -- Astro components and HTML elements (blue)
      vim.cmd(string.format([[highlight! @tag.astro guifg=%s]], colors.base0D))
      vim.cmd(string.format([[highlight! @tag.builtin.astro guifg=%s]], colors.base0D))

      -- Prop/attribute names (red)
      vim.cmd(string.format([[highlight! @tag.attribute.tsx guifg=%s]], colors.base08))
      vim.cmd(string.format([[highlight! @tag.attribute.jsx guifg=%s]], colors.base08))
      vim.cmd(string.format([[highlight! @tag.attribute.astro guifg=%s]], colors.base08))
    end)

    -- Change background when Neovim loses/gains focus
    local focus_group = vim.api.nvim_create_augroup("NvimFocusBackground", { clear = true })

    vim.api.nvim_create_autocmd("FocusLost", {
      group = focus_group,
      callback = function()
        vim.cmd(string.format([[highlight! Normal guibg=%s ctermbg=NONE]], colors.base00))
      end,
    })

    vim.api.nvim_create_autocmd("FocusGained", {
      group = focus_group,
      callback = function()
        vim.cmd(string.format([[highlight! Normal guibg=%s ctermbg=NONE]], colors.base01))
      end,
    })

  end,
}
