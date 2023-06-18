return {
  {
    "kkharji/sqlite.lua",
    lazy = false,
    config = function(_, opts)
      vim.g.sqlite_clib_path = os.getenv("SQLITE_SO_PATH");
    end
  }
}
