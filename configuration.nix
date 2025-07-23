# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{
  config,
  pkgs,
  lib,
  ...
}:
{
  #################################################
  ## Imports
  #################################################

  imports = [
    ./modules/common/nix.nix
    ./modules/common/boot.nix
    ./modules/common/zfs.nix
    ./modules/common/locale.nix
    ./modules/common/networking.nix
    ./modules/common/users.nix
    ./modules/common/bluetooth.nix
    ./modules/common/sshd.nix
    ./modules/common/secrets.nix
    ./modules/common/yubikey.nix
    ./modules/common/global-options.nix
    ./modules/common/syncthing.nix
    ./modules/common/containers
    ./modules/common/keyboards.nix
    ./modules/common/audio.nix
    ./modules/common/pdf.nix
    ./modules/common/packages.nix
    ./modules/common/direnv.nix
    ./modules/common/ssh.nix
    ./modules/common/git.nix
    ./modules/common/printer.nix
    ./modules/common/shell.nix
    ./modules/common/sqlite.nix
    ./modules/common/file-explorer
    ./modules/common/video-player.nix
    ./modules/common/image-viewer.nix
    ./modules/common/sway
    ./modules/common/wayland
    ./modules/common/browser.nix
    ./modules/common/scripts
    ./modules/common/video-editor.nix
    ./modules/common/security.nix
    ./modules/common/graphics.nix
    ./modules/common/systemd.nix
    ./modules/common/home.nix
    ./modules/common/messaging.nix
    ./modules/common/ide.nix
    ./modules/common/crypto.nix
    ./modules/common/claude

    # Our segemented modules
    ./backups/default.nix
  ];

  # TODO: Protect journalctl with setfacl

  # For the await handler:
  # https://fabiobarbero.eu/posts/signalbot/
  # Also https://signald.org/
  # For Window scripting: https://www.reddit.com/r/gnome/comments/mpwm50/gnomemagicwindow_handy_script_to_bring_a_window/
  # For keyboard listening https://github.com/boppreh/keyboard#keyboard.hook

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "22.11"; # Did you read the comment?
}
