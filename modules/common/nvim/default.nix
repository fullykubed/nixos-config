{
  config,
  ...
}:
{
  # Set nvim as system editor
  environment.sessionVariables = {
    EDITOR = "nvim";
  };

  home-manager.users.${config.username} =
    { config, pkgs, ... }:
    {
      xdg.configFile = {
        "nvim" = {
          source = ./config;
          recursive = true;
        };
      };

      home.packages = with pkgs; [
        # Neovim essentials
        tree-sitter
        sqlite

        # Formatters
        stylua
        nixpkgs-fmt
        nodePackages.prettier
        black
        isort
        shfmt

        # Linters
        markdownlint-cli2
        shellcheck
        nodePackages.eslint

        # LSP servers
        lua-language-server
        nil # Nix LSP
        nodePackages.typescript-language-server
        nodePackages.bash-language-server
        python312Packages.python-lsp-server
        yaml-language-server
        vscode-langservers-extracted # HTML, CSS, JSON, ESLint
        unstable.tofu-ls
        unstable.opentofu
        unstable.terraform-ls
        marksman # markdown
        mdx-language-server # mdx
      ];
    };
}
