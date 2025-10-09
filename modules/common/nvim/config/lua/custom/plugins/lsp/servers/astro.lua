-- Astro Language Server configuration
-- https://github.com/withastro/language-tools/tree/main/packages/language-server
--
-- astro-ls can be installed via: npm install -g @astrojs/language-server

return {
  cmd = { "astro-ls", "--stdio" },
  filetypes = { "astro" },
  root_markers = { "package.json", "tsconfig.json", "jsconfig.json", ".git" },
  init_options = {
    typescript = {},
  },
  before_init = function(_, config)
    if config.init_options and config.init_options.typescript and not config.init_options.typescript.tsdk then
      -- Try to find TypeScript SDK path
      local function get_typescript_server_path(root_dir)
        local found_ts = ""
        local function check_dir(path)
          found_ts = path or ""
          if vim.fn.filereadable(found_ts .. "/tsserver.js") == 1 then
            return path
          end
        end
        if root_dir then
          -- Check for project-local TypeScript
          local local_tsserverlib = root_dir .. "/node_modules/typescript/lib"
          if check_dir(local_tsserverlib) then
            return found_ts
          end
        end
        -- Check global TypeScript installations
        local global_ts = vim.fn.system("npm list -g --depth 0 typescript 2>/dev/null")
        if global_ts and not global_ts:match("empty") then
          local global_tsserverlib = vim.fn.trim(vim.fn.system("npm root -g")) .. "/typescript/lib"
          if check_dir(global_tsserverlib) then
            return found_ts
          end
        end
        return nil
      end

      config.init_options.typescript.tsdk = get_typescript_server_path(config.root_dir)
    end
  end,
}