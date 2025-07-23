{ config, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    # unstable.jetbrains.webstorm
    # unstable.jetbrains.goland
    unstable.code-cursor
    unstable.neovim-unwrapped
  ];
  home-manager.users.${config.username} = {
    xdg.desktopEntries = {
      cursor = {
        name = "Cursor";
        comment = "Cursor IDE";
        exec = "${pkgs.unstable.code-cursor}/bin/cursor";
        type = "Application";
      };
    };
  };
}
