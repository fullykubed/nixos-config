return {
  {
    'nvim-pack/nvim-spectre',
    dependencies = {
      'nvim-lua/plenary.nvim',
    },
    keys = {
      { '<leader>S', function() require('spectre').toggle() end, desc = 'Toggle Spectre' },
      { '<leader>sw', function() require('spectre').open_visual({ select_word = true }) end, desc = 'Search current word' },
      { '<leader>sw', function() require('spectre').open_visual() end, mode = 'v', desc = 'Search current selection' },
      { '<leader>sp', function() require('spectre').open_file_search({ select_word = true }) end, desc = 'Search in current file' },
    },
    config = function()
      require('spectre').setup({
        color_devicons = true,
        highlight = {
          ui = 'String',
          search = 'DiffChange',
          replace = 'DiffDelete',
        },
        mapping = {
          ['toggle_line'] = {
            map = 'dd',
            cmd = '<cmd>lua require("spectre").toggle_line()<CR>',
            desc = 'toggle current item',
          },
          ['enter_file'] = {
            map = '<cr>',
            cmd = '<cmd>lua require("spectre.actions").select_entry()<CR>',
            desc = 'goto current file',
          },
          ['send_to_qf'] = {
            map = '<leader>q',
            cmd = '<cmd>lua require("spectre.actions").send_to_qf()<CR>',
            desc = 'send all item to quickfix',
          },
          ['replace_cmd'] = {
            map = '<leader>c',
            cmd = '<cmd>lua require("spectre.state").replace_cmd()<CR>',
            desc = 'input replace vim command',
          },
          ['show_option_menu'] = {
            map = '<leader>o',
            cmd = '<cmd>lua require("spectre").show_options()<CR>',
            desc = 'show option',
          },
          ['run_current_replace'] = {
            map = '<leader>rc',
            cmd = '<cmd>lua require("spectre.actions").run_current_replace()<CR>',
            desc = 'replace current line',
          },
          ['run_replace'] = {
            map = '<leader>R',
            cmd = '<cmd>lua require("spectre.actions").run_replace()<CR>',
            desc = 'replace all',
          },
        },
      })
    end,
  },
}