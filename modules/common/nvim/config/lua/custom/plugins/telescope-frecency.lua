return {
  {
    "nvim-telescope/telescope-frecency.nvim",
    dependencies = {
      "nvim-telescope/telescope.nvim",
      "kkharji/sqlite.lua",
    },
    config = function()
      require("telescope").load_extension("frecency")

      -- Optional: Add a keybinding for frecency
      vim.keymap.set("n", "<leader>sf", function()
        require("telescope").extensions.frecency.frecency({
          workspace = "CWD",
        })
      end, { desc = "[S]earch [F]recency" })
    end,
  },
}
