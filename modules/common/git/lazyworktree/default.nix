{
  config,
  pkgs,
  ...
}:
let
  lazyworktree = pkgs.buildGoModule rec {
    pname = "lazyworktree";
    version = "1.21.1";
    src = pkgs.fetchFromGitHub {
      owner = "chmouel";
      repo = "lazyworktree";
      rev = "v${version}";
      hash = "sha256-5ercx4htJ1GS7nGwK/BeIGrt4ZQLql4Z4pDTVTWZH8o=";
    };
    vendorHash = "sha256-0O8i84mzAYq/VUWn0vbHf218hwXRMAvlfKnBUYXo8Ck=";
    subPackages = [ "cmd/lazyworktree" ];
    meta = {
      description = "A lazygit-inspired TUI for git worktrees";
      homepage = "https://github.com/chmouel/lazyworktree";
      mainProgram = "lazyworktree";
    };
  };
in
{
  home-manager.users.${config.username} = {

    home.packages = [
      lazyworktree # TUI for git worktrees
    ];

    programs.zsh.shellAliases = {
      lw = "lazyworktree";
    };

  };
}
