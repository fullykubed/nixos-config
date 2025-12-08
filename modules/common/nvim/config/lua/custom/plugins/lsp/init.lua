-- LSP Configuration
return {
  -- `lazydev` configures Lua LSP for your Neovim config, runtime and plugins
  -- used for completion, annotations and signatures of Neovim apis
  {
    "folke/lazydev.nvim",
    ft = "lua",
    opts = {
      library = {
        -- Load luvit types when the `vim.uv` word is found
        { path = "${3rd}/luv/library", words = { "vim%.uv" } },
      },
    },
  },
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      -- Useful status updates for LSP.
      { "j-hui/fidget.nvim", opts = {} },

      -- Allows extra capabilities provided by blink.cmp
      "saghen/blink.cmp",

      -- Navigation helper for LSP symbols
      "SmiteshP/nvim-navbuddy",
    },
    config = function()
      -- Diagnostic Config
      vim.diagnostic.config({
        severity_sort = true,
        float = { border = "rounded", source = "if_many" },
        underline = { severity = vim.diagnostic.severity.ERROR },
        signs = vim.g.have_nerd_font and {
          text = {
            [vim.diagnostic.severity.ERROR] = "󰅚 ",
            [vim.diagnostic.severity.WARN] = "󰀪 ",
            [vim.diagnostic.severity.INFO] = "󰋽 ",
            [vim.diagnostic.severity.HINT] = "󰌶 ",
          },
        } or {},
        virtual_text = {
          source = "if_many",
          spacing = 2,
          format = function(diagnostic)
            local diagnostic_message = {
              [vim.diagnostic.severity.ERROR] = diagnostic.message,
              [vim.diagnostic.severity.WARN] = diagnostic.message,
              [vim.diagnostic.severity.INFO] = diagnostic.message,
              [vim.diagnostic.severity.HINT] = diagnostic.message,
            }
            return diagnostic_message[diagnostic.severity]
          end,
        },
      })

      -- Create autocommand for LSP attach
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("kickstart-lsp-attach", { clear = true }),
        callback = function(event)
          local map = function(keys, func, desc, mode)
            mode = mode or "n"
            vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = desc })
          end

          -- LSP keymaps under gl prefix
          map("glr", require("telescope.builtin").lsp_references, "[R]eferences")
          map("gli", require("telescope.builtin").lsp_implementations, "[I]mplementation")
          map("gld", require("telescope.builtin").lsp_definitions, "[D]efinition")
          map("glD", vim.lsp.buf.declaration, "[D]eclaration")
          map("glt", require("telescope.builtin").lsp_type_definitions, "[T]ype Definition")

          -- Leader LSP mappings
          map("<leader>ld", "<cmd>LspInfo<CR>", "[D]iagnostics Info")
          map("<leader>lr", vim.lsp.buf.rename, "[R]ename")
          map("<leader>la", vim.lsp.buf.code_action, "Code [A]ction", { "n", "x" })
          map("<leader>lo", require("telescope.builtin").lsp_document_symbols, "[O]pen Document Symbols")
          map("<leader>lw", require("telescope.builtin").lsp_dynamic_workspace_symbols, "W]orkspace Symbols")

          -- Helper function for client method support
          local function client_supports_method(client, method, bufnr)
            if vim.fn.has("nvim-0.10") == 1 then
              return client:supports_method(method, bufnr)
            else
              return client.supports_method and client.supports_method(method, { bufnr = bufnr })
            end
          end

          local client = vim.lsp.get_client_by_id(event.data.client_id)

          -- Document highlight
          if
            client
            and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_documentHighlight, event.buf)
          then
            local highlight_augroup = vim.api.nvim_create_augroup("kickstart-lsp-highlight", { clear = false })
            vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.document_highlight,
            })

            vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.clear_references,
            })

            vim.api.nvim_create_autocmd("LspDetach", {
              group = vim.api.nvim_create_augroup("kickstart-lsp-detach", { clear = true }),
              callback = function(event2)
                vim.lsp.buf.clear_references()
                vim.api.nvim_clear_autocmds({ group = "kickstart-lsp-highlight", buffer = event2.buf })
              end,
            })
          end

          -- Inlay hints
          if client and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_inlayHint, event.buf) then
            map("<leader>th", function()
              vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = event.buf }))
            end, "[T]oggle Inlay [H]ints")
          end
        end,
      })

      -- Get all server configurations from the servers directory
      local function get_servers()
        local servers = {}

        -- Load all server configurations from the servers directory
        local server_files =
          vim.fn.glob(vim.fn.stdpath("config") .. "/lua/custom/plugins/lsp/servers/*.lua", false, true)

        for _, file in ipairs(server_files) do
          local server_name = vim.fn.fnamemodify(file, ":t:r")
          local ok, server_config = pcall(require, "custom.plugins.lsp.servers." .. server_name)
          if ok then
            servers[server_name] = server_config
          end
        end

        return servers
      end

      -- Setup all servers
      local capabilities = require("blink.cmp").get_lsp_capabilities()
      local servers = get_servers()

      -- Setup each server using new API
      for server_name, server_config in pairs(servers) do
        local config = vim.tbl_deep_extend("force", {
          capabilities = capabilities,
        }, server_config or {})

        -- Add navbuddy to servers that support document symbols
        local original_on_attach = config.on_attach
        config.on_attach = function(client, bufnr)
          if original_on_attach then
            original_on_attach(client, bufnr)
          end

          -- Only attach navbuddy if the client supports document symbols
          local navbuddy_ok, navbuddy = pcall(require, "nvim-navbuddy")
          if navbuddy_ok and client.server_capabilities.documentSymbolProvider then
            navbuddy.attach(client, bufnr)
          end
        end

        -- Register server configuration using new API
        vim.lsp.config(server_name, config)

        -- Enable the server for its filetypes
        vim.lsp.enable(server_name)
      end
    end,
  },
}
