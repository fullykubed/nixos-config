return {
  "tris203/precognition.nvim",
  event = "VeryLazy",
  opts = {
    startVisible = false, -- Start with hints hidden (toggle with :Precognition toggle)
    showBlankVirtLine = true, -- Show virtual line even when empty
    highlightColor = { link = "Comment" }, -- Color for the hints
    hints = {
      Caret = { text = "^", prio = 2 },
      Dollar = { text = "$", prio = 1 },
      MatchingPair = { text = "%", prio = 5 },
      Zero = { text = "0", prio = 1 },
      w = { text = "w", prio = 10 },
      b = { text = "b", prio = 9 },
      e = { text = "e", prio = 8 },
      W = { text = "W", prio = 7 },
      B = { text = "B", prio = 6 },
      E = { text = "E", prio = 5 },
    },
    gutterHints = {
      G = { text = "G", prio = 10 },
      gg = { text = "gg", prio = 9 },
      PrevParagraph = { text = "{", prio = 8 },
      NextParagraph = { text = "}", prio = 8 },
    },
  },
  config = function(_, opts)
    require("precognition").setup(opts)
    -- Create toggle command for easy on/off
    vim.api.nvim_create_user_command("PrecognitionToggle", function()
      require("precognition").toggle()
    end, {})
  end,
  keys = {
    { "<leader>pt", "<cmd>PrecognitionToggle<cr>", desc = "Toggle Precognition hints" },
  },
}