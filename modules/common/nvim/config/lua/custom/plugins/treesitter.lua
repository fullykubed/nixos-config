-- Treesitter - Highlight, edit, and navigate code
return {
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  main = "nvim-treesitter.configs", -- Sets main module to use for opts
  config = function(_, opts)
    require("nvim-treesitter.configs").setup(opts)

    -- Custom TSX/JSX/Astro highlighting configuration
    vim.api.nvim_create_autocmd("FileType", {
      pattern = { "typescriptreact", "javascriptreact", "tsx", "jsx", "astro" },
      callback = function()
        -- Define a consistent color for both React/Astro components and HTML elements
        local tag_color = "#61AFEF" -- Light blue for all tags
        local prop_name_color = "#E06C75" -- Red for prop names

        -- React components and HTML elements (use same color)
        vim.api.nvim_set_hl(0, "@tag.tsx", { fg = tag_color })
        vim.api.nvim_set_hl(0, "@tag.jsx", { fg = tag_color })
        vim.api.nvim_set_hl(0, "@tag.builtin.tsx", { fg = tag_color })
        vim.api.nvim_set_hl(0, "@tag.builtin.jsx", { fg = tag_color })

        -- Astro components and HTML elements (use same color)
        vim.api.nvim_set_hl(0, "@tag.astro", { fg = tag_color })
        vim.api.nvim_set_hl(0, "@tag.builtin.astro", { fg = tag_color })

        -- Prop/attribute names (different color)
        vim.api.nvim_set_hl(0, "@tag.attribute.tsx", { fg = prop_name_color })
        vim.api.nvim_set_hl(0, "@tag.attribute.jsx", { fg = prop_name_color })
        vim.api.nvim_set_hl(0, "@tag.attribute.astro", { fg = prop_name_color })
      end,
    })
  end,
  -- [[ Configure Treesitter ]] See `:help nvim-treesitter`
  opts = {
    ensure_installed = {
      "astro",
      "bash",
      "c",
      "css",
      "diff",
      "editorconfig",
      "fish",
      "git_config",
      "git_rebase",
      "gitattributes",
      "gitcommit",
      "gitignore",
      "go",
      "gomod",
      "gosum",
      "hcl",
      "helm",
      "html",
      "http",
      "ini",
      "javascript",
      "jsdoc",
      "json",
      "json5",
      "jsonc",
      "lua",
      "luadoc",
      "markdown",
      "markdown_inline",
      "nix",
      "requirements",
      "promql",
      "python",
      "query",
      "rust",
      "sql",
      "ssh_config",
      "terraform",
      "tmux",
      "toml",
      "tsx",
      "typescript",
      "vim",
      "vimdoc",
      "xml",
      "yaml",
      "zig",
    },
    -- Autoinstall languages that are not installed
    auto_install = true,
    highlight = {
      enable = true,
      -- Some languages depend on vim's regex highlighting system (such as Ruby) for indent rules.
      --  If you are experiencing weird indenting issues, add the language to
      --  the list of additional_vim_regex_highlighting and disabled languages for indent.
      additional_vim_regex_highlighting = { "ruby" },
    },
    indent = { enable = true, disable = { "ruby" } },
    incremental_selection = {
      enable = true,
      keymaps = {
        init_selection = "<C-space>",
        node_incremental = "<C-space>",
        scope_incremental = false,
        node_decremental = "<bs>",
      },
    },
  },
  -- There are additional nvim-treesitter modules that you can use to interact
  -- with nvim-treesitter. You should go explore a few and see what interests you:
  --
  --    - Incremental selection: Included, see `:help nvim-treesitter-incremental-selection-mod`
  --    - Show your current context: https://github.com/nvim-treesitter/nvim-treesitter-context
  --    - Treesitter + textobjects: https://github.com/nvim-treesitter/nvim-treesitter-textobjects
}

