-- Nix Language Server configuration
return {
  cmd = { "nil" },
  filetypes = { "nix" },
  root_markers = { "flake.nix", ".git" },
  settings = {
    ["nil"] = {
      formatting = {
        command = { "nix", "fmt" },
      },
    },
  },
}

