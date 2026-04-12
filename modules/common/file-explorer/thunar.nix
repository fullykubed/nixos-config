# Thunar is a GUI file manager that is Wayland compatible

{
  config,
  pkgs,
  lib,
  ...
}:
{
  config = lib.mkIf (config.deviceType != "remote-builder") {
    environment.systemPackages = with pkgs; [
      xfce.thunar # GUI file manager
    ];

    #################################################
    ## Thunar Config
    #################################################

    # File manager setup
    programs.thunar = {
      enable = true;
      plugins = with pkgs.xfce; [
        thunar-volman
        thunar-media-tags-plugin
        thunar-archive-plugin
      ];
    };

    home-manager.users.${config.username} = {
      # Set up desktop applications
      xdg.desktopEntries = {
        thunar = {
          name = "File Explorer";
          comment = "The Thunar file explorer";
          exec = "thunar";
          type = "Application";
        };
      };
    };

    services = {
      # Used by Thunar for mounting file systems
      # See https://wiki.gnome.org/Projects/gvfs
      gvfs.enable = true;

      # Thumbnail support for images
      tumbler.enable = true;

      udev.extraRules = ''
        # Don't show our ZFS devices
        ENV{ID_SERIAL_SHORT}=="03F10797044452198042", ENV{UDISKS_IGNORE}="1"
        ENV{ID_SERIAL_SHORT}=="03F10797044452198087", ENV{UDISKS_IGNORE}="1"
        ENV{ID_SERIAL_SHORT}=="PHOC311302VJ118B", ENV{UDISKS_IGNORE}="1"
      '';
    };
  };
}
