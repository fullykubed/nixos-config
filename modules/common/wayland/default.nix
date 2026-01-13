{ config, ... }:
{
  # Variables that enable Wayland compatibility in various tools
  environment.sessionVariables = {

    # Used for forcing wayland usage
    SDL_VIDEODRIVER = "wayland";
    QT_QPA_PLATFORM = "wayland";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    _JAVA_AWT_WM_NONREPARENTING = "1";
    MOZ_ENABLE_WAYLAND = "1";
    NIXOS_OZONE_WL = "1";
  };

  # Enable the windowing system.
  # Note: This does NOT actually start X11 despite the name
  services.xserver.enable = true;

  home-manager.users.${config.username} = {
    xdg.configFile = {
      # Sets up electron to use Wayland by default
      "electron-flags.conf" = {
        source = ./electron/electron-flags.conf;
      };
      "electron-flags13.conf" = {
        source = ./electron/electron13-flags.conf;
      };
    };
  };
}
