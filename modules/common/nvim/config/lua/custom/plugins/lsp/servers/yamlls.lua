-- YAML Language Server configuration
return {
  cmd = { "yaml-language-server", "--stdio" },
  filetypes = { "yaml", "yml", "yaml.docker-compose", "yaml.gitlab" },
  settings = {
    yaml = {
      schemas = {
        -- Add common schemas
        ["https://json.schemastore.org/github-workflow.json"] = "/.github/workflows/*",
        ["https://json.schemastore.org/docker-compose.json"] = "docker-compose*.yml",
        ["https://json.schemastore.org/kubernetes.json"] = "*.k8s.yml",
      },
      format = {
        enable = true,
      },
      validate = true,
      completion = true,
      hover = true,
    },
  },
}