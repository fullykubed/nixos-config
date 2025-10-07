return {
  {
    'rachartier/tiny-glimmer.nvim',
    event = 'VeryLazy',
    config = function()
      require('tiny-glimmer').setup({
        background = {
          enabled = true,
          color = 'grey',
        },
        border = {
          enabled = false,
        },
        timeout = 150,
      })
    end,
  },
}