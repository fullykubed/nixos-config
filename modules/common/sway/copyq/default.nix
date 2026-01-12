{
  config,
  ...
}:
{
  home-manager.users.${config.username} = {
    # CopyQ clipboard manager service
    services.copyq = {
      enable = true;
      systemdTarget = "sway-session.target";
    };

    # CopyQ configuration with dark theme
    xdg.configFile."copyq/copyq.conf" = {
      source = ./copyq.conf;
    };
  };
}
