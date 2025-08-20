return {
  "ggandor/leap.nvim",
  enabled = true,
  keys = {
    { "s", mode = { "n", "x", "o" }, desc = "Leap forward in current window" },
    { "S", mode = { "n", "x", "o" }, desc = "Leap in other windows" },
  },
  config = function()
    require("leap").set_default_mappings()
  end,
}
