{
  ...
}:
{
  imports = [
    ./common/nix
    ./common/boot
    ./common/zswap
    ./common/zfs
    ./common/locale
    ./common/networking
    ./common/time
    ./common/users
    ./common/bluetooth
    ./common/sshd
    ./common/secrets
    ./common/yubikey
    ./common/mitmproxy-credential-proxy
    ./common/global-options
    ./common/syncthing
    ./common/containers
    ./common/keyboards
    ./common/llm-tools
    ./common/audio
    ./common/pdf
    ./common/plocate
    ./common/scanner
    ./common/packages
    ./common/direnv
    ./common/ssh
    ./common/git
    ./common/printer
    ./common/shell
    ./common/tmux
    ./common/sqlite
    ./common/file-explorer
    ./common/video-player
    ./common/image-viewer
    ./common/sway
    ./common/wayland
    ./common/theme
    ./common/browser
    ./common/scripts
    ./common/video-editor
    ./common/security
    ./common/vulnix-scanner
    ./common/graphics
    ./common/systemd
    ./common/sysz
    ./common/home
    ./common/home-manager
    ./common/messaging
    ./common/nvim
    ./common/nono
    ./common/claude
    ./common/crypto
    ./common/recording
    ./common/finance
    ./common/music-player
    ./common/torrent
    ./common/passwords
    ./common/image-editor
    ./common/transcription
    ./common/btop
    ./common/away-notify
    ./common/cpu
    ./common/firmware
    ./common/touchpad
    ./common/backlight
    ./common/battery
    ./common/gpu
    ./common/wakeup
    ./common/hetzner
    ./common/remote-builders
    ./common/controller
    ./common/ccache
    ./common/tailscale
    ./common/nightly-auto-upgrade
    ./patches
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "22.11"; # Did you read the comment?
}
