{ config, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    electrum # BTC
    unstable.wasabiwallet # BTC (privacy focused with coinjoin)
    monero-gui # Monero w/ GUI
    mycrypto # Ethereum
  ];
  home-manager.users.${config.username} = {
    xdg.desktopEntries = {
      wasabi = {
        name = "Bitcoin Wallet";
        comment = "Wasabi Bitcoin Wallet";
        exec = "${pkgs.unstable.wasabiwallet}/bin/wasabiwallet-desktop";
        type = "Application";
      };
    };
  };
}
