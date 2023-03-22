{ config, pkgs, unstable, lib, ... }:
let
  swayModifier = "Mod4";
  scripts = with pkgs; {
    sway-tree-switch = (writeShellScriptBin "sway-tree-switch" (builtins.readFile ./sway/tree-switch.sh));
    sway-workspace-switch = (writeShellScriptBin "sway-workspace-switch" (builtins.readFile ./sway/workspace-switch.sh));
  };
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

  home.file.".config/nvim" = {
    source = ./nvim;
    recursive = true;
  };


  ################################
  ##  Sway
  ################################
  wayland.windowManager.sway = {
    enable = true;
    systemdIntegration = false;
    config = {
      modifier = swayModifier;
      terminal = "alacritty";
      menu = "fuzzel";
      output = {
        "Goldstar Company Ltd LG HDR 4K 0x00000ED1" = { mode = "3840x2160"; pos = "7280 2160"; };
        "Goldstar Company Ltd LG HDR 4K 0x0000D70E" = { mode = "3840x2160"; pos = "7280 0"; };
        "Samsung Electric Company C49RG9x H1AK500000" = { mode = "5120x1440"; pos = "2160 0"; };
        "Samsung Electric Company LS49AG95 HCSW100482" = { mode = "5120x1440"; pos = "2160 1440"; };
        "Goldstar Company Ltd LG HDR 4K 0x00004BD2" = { mode = "3840x2160"; pos = "0 0"; transform = "270"; };
      };
      workspaceOutputAssign = [
        { "workspace" = "1"; output = "Samsung Electric Company C49RG9x H1AK500000"; }
        { "workspace" = "2"; output = "Goldstar Company Ltd LG HDR 4K 0x00004BD2"; }
        { "workspace" = "3"; output = "Goldstar Company Ltd LG HDR 4K 0x0000D70E"; }
        { "workspace" = "4"; output = "Samsung Electric Company LS49AG95 HCSW100482"; }
        { "workspace" = "5"; output = "Goldstar Company Ltd LG HDR 4K 0x00000ED1"; }
        { "workspace" = "messages"; output = "Samsung Electric Company C49RG9x H1AK500000"; }
        { "workspace" = "monitoring"; output = "Samsung Electric Company C49RG9x H1AK500000"; }
        { "workspace" = "editor"; output = "Samsung Electric Company C49RG9x H1AK500000"; }
        { "workspace" = "password"; output = "Samsung Electric Company C49RG9x H1AK500000"; }
      ];
      gaps = {
        inner = 10;
      };
      #      keybindings = {
      #        "${swayModifier}+Shift+w" = "exec ${scripts.sway-workspace-switch}";
      #      };
    };
    extraConfig = ''
      # any window with the title "fzf-switcher" will be floating
      for_window [title="fzf-switcher"] floating enable

      bindsym ${swayModifier}+Shift+w exec sway-workspace-switch
      bindsym ${swayModifier}+Shift+s exec sway-tree-switch

      # for moving the workspaces between monitors
      bindsym ${swayModifier}+Control+Shift+Up move workspace to output up
      bindsym ${swayModifier}+Control+Shift+Down move workspace to output down
      bindsym ${swayModifier}+Control+Shift+Left move workspace to output left
      bindsym ${swayModifier}+Control+Shift+Right move workspace to output right

      # for moving between screens quickly
      bindsym ${swayModifier}+Alt+p [app_id="org.keepassxc.KeePassXC"] focus
      bindsym ${swayModifier}+Alt+s [instance="signal"] focus
      bindsym ${swayModifier}+Alt+l [instance="slack"] focus
      bindsym ${swayModifier}+Alt+e [title="nvim"] focus
      bindsym ${swayModifier}+Alt+b [title="bpytop"] focus
      
      exec dbus-sway-environment
      exec configure-gtk

      exec swaymsg "workspace messages; exec slack; exec signal-desktop"
      exec swaymsg "workspace password; exec keepassxc"
      exec swaymsg "workspace editor; exec alacritty -t nvim"
      exec swaymsg "workspace monitoring; exec alacritty -t bpytop -e bpytop"

      

      # Indicate to systemd that we have started the sway session
      exec_always systemctl --user start sway-session.target
    '';
  };

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
    (import (fetchTarball https://github.com/cachix/devenv/archive/v0.5.1.tar.gz)).default # https://devenv.sh/getting-started/

    ################################
    ##  IDEs and Doc Editors
    ################################
    jetbrains.goland
    jetbrains.webstorm
    jetbrains.pycharm-professional
    jetbrains.datagrip
    libreoffice
    unstable.drawio # TODO: Need to edit desktop config to start with --disable-gpu
    libsForQt5.okular # PDF editing
    marktext

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
    mycrypto # EthereumW

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
    unstable.signal-desktop # X11 (electron)
    slack # X11 (electron)
    unstable.slack-term
    weechat
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
    gscan2pdf # Scanning GUI

    ################################
    ##  Gaming
    ################################
    steam
    lutris

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

      # Common ENV Variables
      export REPOS="$HOME/repos"

      # Bambee configurations
      export BAMBEE_REPOS="$REPOS/bambee"

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
