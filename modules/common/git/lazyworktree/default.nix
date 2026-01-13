{
  config,
  pkgs,
  lib,
  ...
}:
{
  # ===========================================================================
  # Version Options
  # ===========================================================================
  options.versions = {
    lazyworktree = lib.mkOption {
      type = lib.types.str;
      description = "Version of lazyworktree TUI";
    };
    lazyworktreeSrcHash = lib.mkOption {
      type = lib.types.str;
      description = "Source hash for lazyworktree";
    };
    lazyworktreeVendorHash = lib.mkOption {
      type = lib.types.str;
      description = "Vendor hash for lazyworktree Go dependencies";
    };
  };

  # ===========================================================================
  # Configuration
  # ===========================================================================
  config =
    let
      versions = config.versions;

      lazyworktree = pkgs.buildGoModule {
        pname = "lazyworktree";
        version = versions.lazyworktree;
        src = pkgs.fetchFromGitHub {
          owner = "chmouel";
          repo = "lazyworktree";
          rev = "v${versions.lazyworktree}";
          hash = versions.lazyworktreeSrcHash;
        };
        vendorHash = versions.lazyworktreeVendorHash;
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
        home.packages = [ lazyworktree ];

        programs.zsh.shellAliases = {
          lw = "lazyworktree";
        };
      };
    };
}
