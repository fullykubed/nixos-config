# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, ... }:
let

  # Make the unstable branch availble to us in case we need to switch out a particular package
  unstable = import
    (builtins.fetchTarball https://github.com/nixos/nixpkgs/tarball/nixos-unstable)
    # reuse the current configuration
    { config = config.nixpkgs.config; };

  # bash script to let dbus know about important env variables and
  # propagate them to relevent services run at the end of sway config
  # see
  # https://github.com/emersion/xdg-desktop-portal-wlr/wiki/"It-doesn't-work"-Troubleshooting-Checklist
  # note: this is pretty much the same as  /etc/sway/config.d/nixos.conf but also restarts
  # some user services to make sure they have the correct environment variables
  dbus-sway-environment = pkgs.writeTextFile {
    name = "dbus-sway-environment";
    destination = "/bin/dbus-sway-environment";
    executable = true;

    text = ''
      dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=sway
      systemctl --user stop pipewire pipewire-media-session xdg-desktop-portal xdg-desktop-portal-wlr
      systemctl --user start pipewire pipewire-media-session xdg-desktop-portal xdg-desktop-portal-wlr
    '';
  };

  # currently, there is some friction between sway and gtk:
  # https://github.com/swaywm/sway/wiki/GTK-3-settings-on-Wayland
  # the suggested way to set gtk settings is with gsettings
  # for gsettings to work, we need to tell it where the schemas are
  # using the XDG_DATA_DIR environment variable
  # run at the end of sway config
  configure-gtk = pkgs.writeTextFile {
    name = "configure-gtk";
    destination = "/bin/configure-gtk";
    executable = true;
    text =
      let
        schema = pkgs.gsettings-desktop-schemas;
        datadir = "${schema}/share/gsettings-schemas/${schema.name}";
      in
      ''
        export XDG_DATA_DIRS=${datadir}:$XDG_DATA_DIRS
        gnome_schema=org.gnome.desktop.interface
        gsettings set $gnome_schema gtk-theme 'Dracula'
      '';
  };
in
{


  #################################################
  ## Imports
  #################################################

  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix

    # Our segemented modules
    ./systemd-boot/systemd-boot.nix
    ./backups/default.nix

    # Home Manager
    <home-manager/nixos>

    # Custom Global Options
    ./global/default.nix
  ];

  #################################################
  ## Custom Global Config Options
  #################################################
  nix-unstable = unstable;

  #################################################
  ## Virtualization
  #################################################
  virtualisation = {
    podman = {
      enable = true;
      extraPackages = with pkgs; [ zfs ];
      defaultNetwork.dnsname.enable = true;
      dockerCompat = true;
    };
    containers = {
      containersConf = {
        settings = {
          containers = {
            pids_limit = 65536;
          };
          network = {
            network_backend = "netavark";
          };
          engine = {
            helper_binaries_dir = [
              # Fixes DNS resolution in containers
              "${pkgs.netavark}/bin"
              "${pkgs.aardvark-dns}/bin"
            ];
          };
        };
      };
    };
  };

  systemd.enableUnifiedCgroupHierarchy = true;
  # See https://rootlesscontaine.rs/getting-started/common/cgroup2/#enabling-cpu-cpuset-and-io-delegation
  systemd.packages = [
    (pkgs.runCommand "delegate.conf"
      {
        preferLocalBuild = true;
        allowSubstitutes = false;
      } ''
      mkdir -p $out/etc/systemd/system/user@.service.d/
      echo -e "[Service]\nDelegate=cpu cpuset io memory pids" > $out/etc/systemd/system/user@.service.d/delegate.conf
    '')
  ];
  # See https://github.com/k3d-io/k3d/issues/116
  boot.kernel.sysctl."fs.inotify.max_user_instances" = 1280;
  boot.kernel.sysctl."fs.inotify.max_user_watches" = 655360;
  systemd.user.extraConfig = "DefaultLimitNOFILE=65536";

  # Unprivilege ports 80 and above to allow rootless containers to bind to these ports
  boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 80;

  # Allow OOM watching
  boot.kernel.sysctl."kernel.dmesg_restrict" = 0;

  # Podman user service is broken by default
  systemd.user.services.podman.enable = false;
  systemd.user.services.podman2 = {
    unitConfig = {
      Description = "Podman API Service";
      Documentation = "man:podman-system-service(1)";
      StartLimitIntervalSec = "0";
    };
    serviceConfig = {
      ExecStart = "${pkgs.podman}/bin/podman $LOGGING system service -t 0";
      Restart = "always";
      Delegate = "true";
      Type = "exec";
      KillMode = "process";
      Environment = "LOGGING=\"--log-level=info\"";
    };
    wantedBy = [ "default.target" ];
  };
  systemd.user.sockets.podman = {
    socketConfig = {
      TriggerLimitIntervalSec = 0;
      TriggerLimitBurst = 0;
    };
  };

  # Enable linux auditing
  security.auditd.enable = true;

  # Use the systemd-boot EFI boot loader with secureboot.
  # See https://www.rodsbooks.com/efi-bootloaders/controlling-sb.html for detailed info on secureboot + generating and installing keys
  # See https://github.com/frogamic/nix-machines/tree/main/modules/systemd-secure-boot for references to resources for integration with NixOS
  # Note: I edited the nix script to support multiple efi mountpoints
  # Note: If you accidentally delete the boot partition in testing, just run 'bootctl install' to reinstall
  disabledModules = [ "system/boot/loader/systemd-boot/systemd-boot.nix" ];
  boot.loader.systemd-boot = {
    enable = true;
    secureBoot = {
      enable = true;
      keyPath = "/etc/nixos/systemd-boot/DB.key";
      certPath = "/etc/nixos/systemd-boot/DB.crt";
    };
    efiSysMountPoints = [ "/boot0" "/boot1" ];
    configurationLimit = 10;
    memtest86.enable = true;
  };
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelParams = [
    "nohibernate" # With ZFS we cannot hibernate (also poses a security issue due to RAM persistence)
    "zfs.zfs_max_recordsize=16777216" # Allow large 16M record sizes
    "zfs.zfs_dirty_data_max_percent=50" # Allows 50% of RAM to be consumed by writes before throttling
    "zfs.zfs_dirty_data_sync=1073741824" # Allows 1GiB of data to accumulate before forcing a disk sync more often than 5 sec interval
    "amdgpu.ras_enable=0" # disable RAS which was causing hw errors with the W6800 gpu
  ];

  networking.hostName = "jack-desktop"; # Define your hostname.
  networking.hostId = "925bf176";
  networking.networkmanager.enable = true;
  networking.wireless.enable = false; # Disable wpa_supplicant as we are using network manager

  # Set your time zone.
  time.timeZone = "America/Indianapolis";

  # The okta_core useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.
  networking.useDHCP = false;
  networking.interfaces.enp5s0.useDHCP = true;
  networking.interfaces.enp6s0.useDHCP = true;

  # Fixes dns lookups at local host addresses
  # https://github.com/NixOS/nix/issues/5441
  networking.hosts."127.0.0.1" = [ "this.pre-initializes.the.dns.resolvers.invalid." ];

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  # Enable the windowing system.
  # Note: This does NOT actually start X11 despite the name
  services.xserver.enable = true;

  # Pull in the graphics drivers
  services.xserver.videoDrivers = [ "amdgpu" ];

  # Enable open gl
  hardware.opengl = {
    enable = true;
    driSupport = true;
    driSupport32Bit = true;
  };

  services.xserver.layout = "us";

  ################################
  ## Security
  ################################
  security.polkit.enable = true;

  ################################
  ## Display Manager
  ##
  ## See https://nixos.wiki/wiki/Sway
  ################################
  # enable sway window manager
  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
    extraPackages = with pkgs; [
      swaylock
      swayidle
      swayr # window switcher
      wl-clipboard
      wf-recorder
      mako # notification daemon
      grim
      #kanshi
      slurp
      fuzzel # Launcher
      dbus-sway-environment
      configure-gtk
      xdg-utils # for opening default programs when clicking links
      glib # gsettings
      dracula-theme # gtk theme
      unstable.sov
    ];
    extraSessionCommands = ''
      export SDL_VIDEODRIVER=wayland
      export QT_QPA_PLATFORM=wayland
      export QT_WAYLAND_DISABLE_WINDOWDECORATION="1"
      export _JAVA_AWT_WM_NONREPARENTING=1
      export MOZ_ENABLE_WAYLAND=1
    '';
  };

  # Disable the login manager
  services.xserver.displayManager.lightdm.enable = false;

  # Setup waybar
  programs.waybar.enable = true;

  # Portals are the mechanism for sharing audio and video across applications
  xdg.portal = {
    enable = true;

    # Only use for wl-roots based systems
    wlr.enable = true;

    # Do NOT enable this; adds extra 30 seconds to boot time and causes failures
    # https://github.com/NixOS/nixpkgs/issues/156950
    gtkUsePortal = false;

    # For screen sharing in gnome
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
    ];
  };

  fonts = {
    fonts = with pkgs; [
      nerdfonts
      noto-fonts
      noto-fonts-cjk
      noto-fonts-emoji
      font-awesome
      source-han-sans
      source-han-sans-japanese
      source-han-serif-japanese
    ];
    fontconfig.defaultFonts = {
      serif = [ "Noto Serif" "Source Han Serif" ];
      sansSerif = [ "Noto Sans" "Source Han Sans" ];
    };
  };

  # Systemd target so that we can start and stop background services
  # that depend on a sway session
  systemd.user.targets.sway-session = {
    description = "Sway compositor session";
    documentation = [ "man:systemd.special" ];
    bindsTo = [ "graphical-session.target" ];
    wants = [ "graphical-session-pre.target" ];
    after = [ "graphical-session-pre.target" ];
  };


  ################################
  ## ZFS
  ################################
  services.zfs.autoScrub.enable = true;
  services.zfs.trim.enable = true;

  ################################
  ## Printing
  ################################
  services.printing.enable = true;

  ################################
  ## Audio
  ## See https://nixos.wiki/wiki/PipeWire
  ################################
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  ################################
  ## Users
  ################################
  users.users.jack = {
    isNormalUser = true;
    extraGroups = [ "wheel" "scanner" "lp" ];
    subUidRanges = [
      {
        count = 65543;
        startUid = 100001;
      }
    ];
    subGidRanges = [
      {
        count = 65543;
        startGid = 100001;
      }
    ];
  };
  users.groups.jack.members = [ "jack" ];
  home-manager.users.jack = import ./home-manager/default.nix { inherit pkgs lib config unstable; };


  environment.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };


  ################################
  ## System Packages
  ################################
  nixpkgs.config.allowUnfree = true;
  environment.systemPackages = with pkgs; [
    wget # TODO: Remove from scripts

    ################################
    ##  Terminal Management
    ################################
    unstable.neovim
    alacritty
    terminator

    ################################
    ##  Virtualization Utilities
    ################################
    slirp4netns
    fuse-overlayfs

    ################################
    ##  Nix Debugging Utilities
    ################################
    cntr

    ################################
    ##  Boot Utilities
    ################################
    tpm2-tools
    tpm2-abrmd
    efibootmgr
    efitools

    ################################
    ##  Parsers
    ################################
    jq # JSON parser
    yq # YAML parser

    ################################
    ##  General Tooling
    ################################
    unzip # ZIP archive management
    rsync # Local file syncronization
    python310 # Scripting language
    pv # Stream monitoring
    exa # "Better" ls written in rust
    ripgrep # "Better" grep written in rust
    fd # "Better" find written in rust
    sysstat # Performance monitoring tools (e.g., iostat, pidstat)
    bind # Interfacing with dns (e.g., dig)
    fio # Testing file system speed
    cryptsetup # Working with dmcrypt
    jump # For directory navigation (written in go)
    parallel # Executing commands in parallel
    fzf # For fuzzy finding
    unstable.croc # For sending secured files

    ################################
    ##  Process Isolation + Securtiy
    ################################
    bubblewrap # Unprivileged sandboxing tool
    wireguard-tools # User-space tools for interfacing with wireguard kernel module
    openssl_3_0 # Certificate generation
    yubikey-manager # Working with yubikey hardware tokens
    xorg.xeyes # For checking if an app is running in x compat mode
    su # For UID mapping

    ################################
    ##  Build Tools
    ################################
    gnumake
    gcc
    clang_13
    fakeroot
    ncurses
    flex
    bison
    pkg-config
    killall

    ################################
    ##  Word Lists
    ################################
    aspell
    aspellDicts.en

    ################################
    ##  Low-Level Graphics Tooling
    ################################

    # Note: See https://mozillagfx.wordpress.com/2021/10/30/switching-the-linux-graphics-stack-from-glx-to-egl/
    glxinfo # CLI for debugging some issues with GLX, powers X graphics (older)
    egl-wayland # CLI for debugging some issues with the EGLStreams; EGLStreams powers Wayland desktop (newer)

    ################################
    ##  Low-Level Disk Tooling
    ################################
    smartmontools # SMART cli for disk health checking
    hdparm # Interfacing with hard didks
    nvme-cli # Interfacing with nvme disks

    ################################
    ##  General Debugging
    ################################
    lnav # Structured log file navigator
    dmidecode # Reads info about connected devices from MOBO through SMBIOS/DMI
    htop # Interactive process monitoring
    bpytop # Better interactive process monitoring
    lshw # Alternative way to query hardware
    lm_sensors # For reading hardware sensors
    psensor # For displaying hardware sensors graphically
    helvum # Controlling pipewire
    radeontop # GPU monitoringmem

    ################################
    ##  Network Tooling
    ################################
    mtr # tracerout
    bind # dns utils

    ################################
    ##  External Devices
    ################################
    android-udev-rules # Working with pixel
    android-tools # Working with pixel (and other android devices)

    ################################
    ##  Windows Emulation
    ################################
    wineWowPackages.waylandFull
    winetricks
  ];

  # Configure syncthing for filesystem sync across devices
  services.syncthing = {
    enable = true;
    user = "jack";
    group = "jack";
    dataDir = "/home/jack";
    systemService = true;
    overrideDevices = true;
    overrideFolders = true;
    devices = {
      "zenbook" = { id = "5AO3FST-KPWRUCV-ASJQLMI-BHY2LEY-X5LKA7I-UWEZOZT-MSKLFFS-45SBFAI"; };
      "bambee_mac" = { id = "CRVU545-X32YNWD-PRMIT6Z-XILLZ4C-F433UCH-VNG7SBI-CCFZAGS-UU3KNAM"; };
      "pixel6" = { id = "C475M4E-JGQ6PNA-PQD5WTV-OQRBRXW-AGQO6ZI-WS4JO6U-DSJR7OK-T2RWIQN"; };
    };
    folders = {
      "keepass" = {
        id = "keepass";
        label = "Keepass";
        path = "/home/jack/keepass";
        devices = [ "zenbook" "bambee_mac" "pixel6" ];
      };
      "docs" = {
        id = "djyz3-mgw9k";
        label = "Documents";
        path = "/home/jack/docs";
        devices = [ "zenbook" ];
      };
      "pixel_camera" = {
        id = "pixel_6_jgkv-photos";
        label = "S9_Camera";
        path = "/home/jack/camera/pixel";
        devices = [ "pixel6" ];
        type = "receiveonly";
      };
    };

  };

  # Secrets management
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  # Disable ipv6 b/c we do not need it
  networking.enableIPv6 = false;

  networking.firewall = {
    enable = true;

    # Enable the wireguard port
    allowedUDPPorts = [ 51820 ];

    # if packets are still dropped, they will show up in dmesg
    logReversePathDrops = true;
  };

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

  # Configure autoupdating
  system.autoUpgrade.enable = true;
  system.autoUpgrade.allowReboot = true;
  system.autoUpgrade.dates = "04:00";

  # Configure automatic package garbage collection
  nix.gc.automatic = true;
  nix.gc.dates = "05:00";

  # Ensure the cpu doesn't get blasted
  nix.daemonCPUSchedPolicy = "idle";
  nix.settings.max-jobs = 16;
}

