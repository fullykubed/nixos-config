# Home Manager user configuration
{
  config,
  stylix-home-module,
  nix-index-database-home-module,
  ...
}:
{
  home-manager = {
    backupFileExtension = "hm-backup";
    useGlobalPkgs = true;
    useUserPackages = true;
    sharedModules = [
      stylix-home-module
      nix-index-database-home-module
    ];
    users.${config.username} = {
      home.stateVersion = "22.11";

      # Disable manual generation to avoid builtins.toFile warning
      # See: https://github.com/nix-community/home-manager/issues/7935
      manual.manpages.enable = false;
    };
    users.root = {
      home.stateVersion = "22.11";
      manual.manpages.enable = false;
    };
  };
}
