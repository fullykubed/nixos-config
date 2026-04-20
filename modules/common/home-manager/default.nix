# Home Manager user configuration
{
  config,
  stylix-home-module,
  nix-index-database-home-module,
  ...
}:
{
  # Pre-create ~/.config owned by the user before any systemd services run.
  # Without this, systemd-tmpfiles silently creates it as root:root when a
  # service (e.g. syncthing) requests a subdirectory inside it — which blocks
  # home-manager activation with "mkdir: cannot create directory ~/.config/systemd".
  # The 'd' type resets ownership even if the directory already exists.
  systemd.tmpfiles.rules = [
    "d '/home/${config.username}/.config' 0700 '${config.username}' '${config.username}' - -"
  ];

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

      # Use sd-switch to intelligently restart changed user services on rebuild
      systemd.user.startServices = "sd-switch";
    };
    users.root = {
      home.stateVersion = "22.11";
      manual.manpages.enable = false;
    };
  };
}
