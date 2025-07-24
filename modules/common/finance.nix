{ config, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    homebank # Personal finance management
  ];
  home-manager.users.${config.username} = {
    xdg.desktopEntries = {
      homebank = {
        name = "HomeBank";
        comment = "Free easy personal accounting for all";
        exec = "${pkgs.homebank}/bin/homebank";
        type = "Application";
      };
    };
  };
}