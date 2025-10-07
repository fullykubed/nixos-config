return {
  "kiyoon/telescope-insert-path.nvim",
  dependencies = { "nvim-telescope/telescope.nvim" },
  config = function()
    require("telescope").load_extension("insert_path")
  end,
  keys = {
    {
      "<leader>fi",
      function()
        require("telescope").extensions.insert_path.insert_path()
      end,
      desc = "Insert file path",
      mode = { "n", "i" },
    },
    {
      "<leader>fI",
      function()
        require("telescope").extensions.insert_path.insert_path({ path_type = "absolute" })
      end,
      desc = "Insert absolute file path",
      mode = { "n", "i" },
    },
  },
}