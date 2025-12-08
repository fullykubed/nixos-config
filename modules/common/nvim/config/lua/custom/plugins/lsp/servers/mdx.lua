-- MDX Language Server configuration

-- Recursively search upwards for node_modules/typescript/lib
local function find_typescript_lib(start_dir)
  local current_dir = start_dir

  while current_dir and current_dir ~= "/" do
    local tsdk_path = current_dir .. "/node_modules/typescript/lib"
    if vim.fn.isdirectory(tsdk_path) == 1 then
      return tsdk_path
    end

    -- Move up one directory
    current_dir = vim.fn.fnamemodify(current_dir, ":h")
  end

  return nil
end

return {
  cmd = { "mdx-language-server", "--stdio" },
  filetypes = { "mdx" },
  root_markers = { "package.json", ".git" },
  before_init = function(params, config)
    -- Get root_dir from params (LSP InitializeParams)
    local root_dir = nil
    if params.rootUri then
      root_dir = vim.uri_to_fname(params.rootUri)
    elseif params.rootPath then
      root_dir = params.rootPath
    else
      root_dir = config.root_dir or vim.fn.getcwd()
    end

    local tsdk = find_typescript_lib(root_dir)

    params.initializationOptions = params.initializationOptions or {}
    if tsdk then
      params.initializationOptions.typescript = {
        tsdk = tsdk,
        enabled = true,
      }
    else
      -- Disable TypeScript features if typescript library not found
      params.initializationOptions.typescript = {
        enabled = false,
      }
    end
  end,
}