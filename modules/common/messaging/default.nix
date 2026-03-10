{
  config,
  pkgs,
  nixpkgs-unstable,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    discord
    nixpkgs-unstable.signal-desktop # TODO: this does not have wayland enabled
    slack
    signal-cli # TODO: Need to follow instructions here to work: https://github.com/AsamK/signal-cli/issues/701
  ];
  home-manager.users.${config.username} = {
    xdg.desktopEntries = {
      slack = {
        name = "Slack";
        comment = "Slack";
        exec = "${pkgs.slack}/bin/slack";
        type = "Application";
      };
      signal = {
        name = "Signal";
        comment = "Signal";
        exec = "${nixpkgs-unstable.signal-desktop}/bin/signal-desktop";
        type = "Application";
      };
      discord = {
        name = "Discord";
        comment = "Discord";
        exec = "${pkgs.discord}/bin/discord";
        type = "Application";
      };
    };
  };
}
