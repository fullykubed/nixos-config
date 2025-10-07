return {
  "NMAC427/guess-indent.nvim",
  config = function()
    require("guess-indent").setup({
      -- Auto command to run when opening a buffer
      auto_cmd = true,
      -- Override default vim.o settings for indentation
      override_editorconfig = false,
      -- A list of filetypes for which the auto command gets disabled
      filetype_exclude = {
        "netrw",
        "tutor",
        "help",
        "neo-tree",
      },
      -- A list of buffer types for which the auto command gets disabled
      buftype_exclude = {
        "help",
        "nofile",
        "terminal",
        "prompt",
      },
    })
  end,
}