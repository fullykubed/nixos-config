return {
  "nacro90/numb.nvim",
  event = "CmdlineEnter",
  config = function()
    require("numb").setup({
      show_numbers = true, -- Show line numbers in the window
      show_cursorline = true, -- Show cursorline in the window
      hide_relativenumbers = true, -- Hide relative numbers in the window
      number_only = false, -- Only peek when command is just a number
      centered_peeking = true, -- Center the peeked line
    })
  end,
}