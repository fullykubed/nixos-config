{ config, pkgs, unstable, lib, ... }:
let
  scripts = with pkgs; { };
in
{
  home.stateVersion = "22.11";

  # Set up default directories in $HOME
  xdg.userDirs = {
    enable = true;
    desktop = "$HOME/desktop";
    documents = "$HOME/docs";
    music = "$HOME/media";
    videos = "$HOME/media";
    templates = "$HOME/docs";
    pictures = "$HOME/camera";
    download = "$HOME/downloads";
    publicShare = "$HOME/public";
  };

  ################################
  ##  Git
  ################################
  programs.git = {
    enable = true;
    lfs.enable = true;
    userEmail = "jack@fullstackjack.io";
    userName = "jclangst";
  };

  ################################
  ##  Config Files
  ################################
  xdg.configFile = {
    "nvim" = { source = ./nvim; recursive = true; };
  };


  ################################
  ##  Sway
  ################################
  ################################
  ##  Setup Starship
  ################################
  programs.starship = {
    enable = true;
    enableBashIntegration = true;
    settings = {
      format = "$username$hostname$directory$git_branch$git_state$git_status$cmd_duration$line_break$character";
      directory = {
        style = "bold 33";
      };
      character = {
        success_symbol = "[❯](purple)";
        error_symbol = "[❯](red)";
      };
      git_branch = {
        format = "[$branch]($style)";
        style = "34";
      };
      git_status = {
        format = "[[(:$conflicted$untracked$modified$staged$renamed$deleted)](#cbffbe) ($ahead_behind$stashed)]($style)";
        conflicted = "X";
        untracked = "U";
        modified = "M";
        staged = "S";
        renamed = "R";
        deleted = "D";
        stashed = "^";
      };
      git_state = {
        format = "\([$state( $progress_current/$progress_total)]($style)\) ";
        style = "bright-black";
      };
      cmd_duration = {
        format = "[$duration]($style) ";
        style = "white";
      };
    };
  };

  home.packages = with pkgs; [
    # Need to sort
    unstable.lazygit
    go
    cargo
    luajitPackages.luarocks
    unstable.php82
    unstable.php82Packages.composer
    python310
    python310Packages.pip
    ruby_3_1
    jdk
    julia
    powershell
    fish
    nodejs
    tree-sitter
    stylua

    ################################
    ##  Browsers
    ################################
    firefox
    chromium

    ################################
    ##  Dev Utilities
    ################################
    direnv
    (import (fetchTarball https://github.com/cachix/devenv/archive/latest.tar.gz)).default # https://devenv.sh/getting-started/

    ################################
    ##  IDEs and Doc Editors
    ################################
    libreoffice
    unstable.drawio # TODO: Need to edit desktop config to start with --disable-gpu
    libsForQt5.okular # PDF editing

    ################################
    ##  KVM
    ################################
    barrier

    ################################
    ##  Cryptocurrency
    ################################
    electrum # BTC
    wasabiwallet # BTC (privacy focused with coinjoin)
    monero-gui # Monero w/ GUI
    mycrypto # Ethereum

    ################################
    ##  Password Managers
    ################################
    keepassxc # Wayland (thank god)
    gnupg

    ################################
    ##  Containers and Kubernetes
    ################################
    podman
    podman-compose
    kubectl
    kubectx
    k9s

    ################################
    ##  Yubikiey Customization
    ################################
    yubikey-personalization
    yubikey-personalization-gui

    ################################
    ##  Messaging
    ################################
    teams # X11 (electron)
    discord # X11 (electron)
    # Fix for https://github.com/NixOS/nixpkgs/issues/222043
    (unstable.signal-desktop.overrideAttrs
      (old: {
        preFixup = old.preFixup + ''
          gappsWrapperArgs+=(
            --add-flags "--enable-features=UseOzonePlatform"
            --add-flags "--ozone-platform=wayland"
          )
        '';
      }))
    slack
    signal-cli # TODO: Need to follow instructions here to work: https://github.com/AsamK/signal-cli/issues/701

    ################################
    ##  File Sharing
    ################################
    qbittorrent

    ################################
    ##  Media Players
    ################################
    vlc # Needs X11, but actually seems to work on video files
    spotify # X11 (electron)
    spotify-tui

    ################################
    ##  Recording and Streaming
    ################################
    unstable.obs-studio # Recording + streaming; unstable for wayland supported version; TODO: Move off unstable in next release
    pavucontrol # For controlling audio sinks
    imagemagick # For image manipulation
    gimp # Image manipulation
    zoom-us

    ################################
    ##  Scanners and Printers
    ################################

    # Disabled test until https://github.com/NixOS/nixpkgs/issues/223446 is resolved
    unstable.gscan2pdf # Scanning GUI

    ################################
    ##  Gaming
    ################################
    steam
    lutris

    ################################
    ## Databases 
    ################################
    sqlite

  ] ++ (builtins.attrValues scripts);

  nixpkgs.config = {
    allowUnfree = true;
  };

  home.shellAliases = {
    # For syncing the config
    s = "/home/jack/repos/nixos/sync.sh";

    # For replacing grep with rg
    grep = "rg -uu";
    g = "rg -uu";

    # For monitoring disk usage
    zio = "watch -n 1 zpool iostat -lvy 1 1";

    # For checking stats on a zfs pool
    zstat = "sudo zpool status -v";

    # For checkings block stats on a zfs dataset
    zblock = "sudo zdb -bbb";
  };

  home.sessionVariables = {
    # Used for getting the shared object file for working with sqlite databases
    SQLITE_SO_PATH = "${pkgs.sqlite.out}/lib/libsqlite3.so";

    # Set the repo directories for use in dynamic repo scripts
    REPOS = "$HOME/repos";
    BAMBEE_REPOS = "$HOME/repos/bambee";
  };

  programs.bash = {
    enable = true;

    # For more, look here: https://sidneyliebrand.medium.com/how-fzf-and-ripgrep-improved-my-workflow-61c7ca212861
    bashrcExtra = with pkgs; let

      # Custom scripts to add to the bash path (name = src)
      extraScripts = {
        syslog = ./util/syslog.sh;
        pk = ./util/pk.sh;
        vpn = ./util/vpn.sh;

        sp = ./sway/sp.sh;
      };

    in
    ''
            # Used for adding jump autocomplete
            eval "$(jump shell bash)"

            # Setup direnv
            eval "$(direnv hook bash)"
            export DIRENV_WARN_TIMEOUT=60s

            # Add my custom scripts to the path
            export PATH="$PATH:${lib.strings.concatStringsSep ":"
      (lib.mapAttrsToList (name: src: (writeScriptBin name (builtins.readFile src)).outPath + "/bin") extraScripts)
      }"
    '';

    # Make sure the desktop entries show up
    profileExtra = ''
      export XDG_DATA_DIRS=\"$HOME/.nix-profile/share:$XDG_DATA_DIRS\"

      if [ "$(tty)" = "/dev/tty1" ]; then
        export XDG_CURRENT_DESKTOP=sway
        exec systemd-cat -t sway sway
      fi
    '';
  };

}
