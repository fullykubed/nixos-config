{ config, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    keepassxc # Password manager
  ];
  home-manager.users.${config.username} = {
    xdg.desktopEntries = {
      keepassxc = {
        name = "Password Manager";
        comment = "KeePassXC Cross-platform password manager";
        exec = "${pkgs.keepassxc}/bin/keepassxc";
        type = "Application";
      };
    };
  };
}