# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{
  ...
}:
{
  #################################################
  ## Imports
  #################################################

  imports = [
    ./modules/common/nix
    ./modules/common/boot
    ./modules/common/zfs
    ./modules/common/locale
    ./modules/common/networking
    ./modules/common/time
    ./modules/common/users
    ./modules/common/bluetooth
    ./modules/common/sshd
    ./modules/common/secrets
    ./modules/common/yubikey
    ./modules/common/global-options
    ./modules/common/syncthing
    ./modules/common/containers
    ./modules/common/keyboards
    ./modules/common/audio
    ./modules/common/pdf
    ./modules/common/scanner
    ./modules/common/packages
    ./modules/common/direnv
    ./modules/common/ssh
    ./modules/common/git
    ./modules/common/printer
    ./modules/common/shell
    ./modules/common/tmux
    ./modules/common/sqlite
    ./modules/common/file-explorer
    ./modules/common/video-player
    ./modules/common/image-viewer
    ./modules/common/sway
    ./modules/common/wayland
    ./modules/common/theme
    ./modules/common/browser
    ./modules/common/scripts
    ./modules/common/video-editor
    ./modules/common/security
    ./modules/common/graphics
    ./modules/common/systemd
    ./modules/common/home
    ./modules/common/messaging
    ./modules/common/nvim
    ./modules/common/claude
    ./modules/common/crypto
    ./modules/common/recording
    ./modules/common/finance
    ./modules/common/music-player
    ./modules/common/torrent
    ./modules/common/passwords
    ./modules/common/image-editor
    ./modules/common/transcription
    ./modules/common/imagemagick

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
