{
  config,
  pkgs,
  lib,
  nixpkgs-unstable,
  ...
}:
{
  config = lib.mkIf (config.deviceType != "remote-builder") {
    environment.systemPackages = with pkgs; [
      nixpkgs-unstable.wasabiwallet # BTC (privacy focused with coinjoin)
      monero-gui # Monero w/ GUI

    ];
    home-manager.users.${config.username} = {
      xdg.desktopEntries = {
        wasabi = {
          name = "Bitcoin Wallet";
          comment = "Wasabi Bitcoin Wallet";
          exec = "${nixpkgs-unstable.wasabiwallet}/bin/wasabiwallet-desktop";
          type = "Application";
        };
      };
    };
  };
}
