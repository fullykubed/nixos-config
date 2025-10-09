-- Tofu/Terraform Language Server configuration
return {
  cmd = { "tofu-ls", "serve" },
  filetypes = { "terraform", "tf", "tofu", "terraform-vars" },
  root_markers = { ".terraform", "*.tf", "*.tfvars", ".git" },
  init_options = {
    experimentalFeatures = {
      validateOnSave = false,
      prefillRequiredFields = true,
    },
    tofu = {
      timeout = "60s",
      logFilePath = "",
    },
    indexing = {
      ignorePaths = {},
      ignoreDirectoryNames = { ".terragrunt-cache" },
    },
  },
  single_file_support = true,
  on_attach = function(client, bufnr)
    -- Override capabilities for better completion and references
    client.server_capabilities = vim.tbl_deep_extend("force", client.server_capabilities or {}, {
      completionProvider = {
        resolveProvider = true,
        triggerCharacters = { ".", "[", '"' },
      },
      referencesProvider = true,
    })

    -- Get the buffer's filename
    local bufname = vim.api.nvim_buf_get_name(bufnr)
    local workspace_dir = vim.fn.fnamemodify(bufname, ":p:h")
    local terraform_dir = workspace_dir .. "/.terraform"

    -- Check if providers are initialized, if not, offer to initialize
    if vim.fn.isdirectory(terraform_dir) == 0 then
      vim.defer_fn(function()
        vim.notify(
          "Tofu providers not initialized. Run :TofuInit to download provider schemas for completions",
          vim.log.levels.WARN
        )
      end, 100)
    end

    -- Command to initialize providers
    vim.api.nvim_buf_create_user_command(bufnr, "TofuInit", function()
      vim.notify("Initializing Tofu providers in background...", vim.log.levels.INFO)

      -- Run tofu init asynchronously
      vim.fn.jobstart({ "sh", "-c", "cd " .. vim.fn.shellescape(workspace_dir) .. " && tofu init -upgrade" }, {
        on_exit = function(_, exit_code)
          if exit_code == 0 then
            vim.schedule(function()
              vim.notify(
                "Tofu providers initialized. Please save and reopen files to refresh LSP.",
                vim.log.levels.INFO
              )
              -- Don't try to restart LSP automatically as it causes issues with references
              -- Users should save and reopen files manually for best results
            end)
          else
            vim.schedule(function()
              vim.notify(
                "Failed to initialize providers (exit code: " .. exit_code .. ")",
                vim.log.levels.ERROR
              )
            end)
          end
        end,
        on_stderr = function(_, data)
          if data and #data > 0 and data[1] ~= "" then
            vim.schedule(function()
              vim.notify("Tofu init: " .. table.concat(data, "\n"), vim.log.levels.WARN)
            end)
          end
        end,
      })
    end, { desc = "Initialize Tofu providers", force = true })

    -- Also create a TerraformInit alias for muscle memory
    vim.api.nvim_buf_create_user_command(bufnr, "TerraformInit", function()
      vim.cmd("TofuInit")
    end, { desc = "Alias for :TofuInit", force = true })

    -- Add keybinding for TofuInit
    vim.keymap.set(
      "n",
      "<leader>li",
      "<cmd>TofuInit<CR>",
      { buffer = bufnr, desc = "[L]SP [I]nitialize Tofu providers" }
    )
  end,
}