# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, ... }: {
  #################################################
  ## Imports
  #################################################

  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix

    # Our segemented modules
    ./backups/default.nix
    ./disable-wakeup-triggers/default.nix

    # Custom Global Options
    ./global/default.nix

    # Window manager setup
    ./sway/default.nix
  ];

  #################################################
  ## Ergodox EZ Keyboard Mappings
  #################################################
 services.udev.extraRules = ''
    ATTRS{idVendor}=="16c0", ATTRS{idProduct}=="04[789B]?", ENV{ID_MM_DEVICE_IGNORE}="1"
    ATTRS{idVendor}=="16c0", ATTRS{idProduct}=="04[789A]?", ENV{MTP_NO_PROBE}="1"
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="16c0", ATTRS{idProduct}=="04[789ABCD]?", MODE:="0666"
    KERNEL=="ttyACM*", ATTRS{idVendor}=="16c0", ATTRS{idProduct}=="04[789B]?", MODE:="0666"
  '';

  #################################################
  ## Gaming
  #################################################
  programs.steam.enable = true;

  #################################################
  ## Virtualization
  #################################################
  virtualisation = {
    podman = {
      enable = true;
      extraPackages = with pkgs; [ zfs ];
      defaultNetwork.settings.dns_enabled = true;
      dockerCompat = false;
      autoPrune = {
        enable = true;
        flags = ["--all"];
        dates = "weekly";
      };
    };
    containers = {
      storage = {
        settings = {
          storage = {
            driver = "overlay";
          };
        };
      };
      containersConf = {
        settings = {
          containers = {
            pids_limit = 65536;
            default_ulimits = ["nofile=65536:65536"];
          };
          network = {
            network_backend = "netavark";
          };
          engine = {
            helper_binaries_dir = [
              "${pkgs.podman}/libexec/podman"
            ];
          };
        };
      };
    };
  };

  # Podman user service is broken by default
  systemd.user.services.podman.enable = false;

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

  # Allow OOM watching
  boot.kernel.sysctl."kernel.dmesg_restrict" = 0;

  # Enable linux auditing
  security.auditd.enable = true;

  boot.loader = {
    systemd-boot.enable = lib.mkForce false;
    efi = {
      efiSysMountPoint = "/boot";
      canTouchEfiVariables = true;
    };
  };
  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/etc/secureboot";
  };
  boot.kernelParams = [
    "nohibernate" # With ZFS we cannot hibernate (also poses a security issue due to RAM persistence)
    "zfs.zfs_max_recordsize=16777216" # Allow large 16M record sizes
    "zfs.zfs_dirty_data_max_percent=50" # Allows 50% of RAM to be consumed by writes before throttling
    "zfs.zfs_dirty_data_sync=1073741824" # Allows 1GiB of data to accumulate before forcing a disk sync more often than 5 sec interval
    "amdgpu.ras_enable=0" # disable RAS which was causing hw errors with the W6800 gpu
    "acpi_enforce_resources=lax" # allows for hardware sensors from the motherboard to appear
  ];

  # Copies the EFI partition to a backup partition. This allows us to boot even if the first
  # drive becomes corrupted.
  system.activationScripts = {
    boot-sync.text = "${pkgs.rsync}/bin/rsync -avq --delete /boot/ /boot1/";
  };


  networking.hostName = "jack-desktop"; # Define your hostname.
  networking.hostId = "925bf176";
  networking.networkmanager.enable = true;
  networking.wireless.enable = false; # Disable wpa_supplicant as we are using network manager

  # Set your time zone.
  time.timeZone = "America/Indianapolis";

  # The useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.
  networking.useDHCP = false;
  networking.interfaces.enp75s0.useDHCP = true;

  # Fixes dns lookups at local host addresses
  # https://github.com/NixOS/nix/issues/5441
  networking.hosts."127.0.0.1" = [ "this.pre-initializes.the.dns.resolvers.invalid." ];

  networking.nameservers = ["1.1.1.1" "8.8.8.8" ];

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

  # enable amd gpu debugging
  programs.corectrl.enable = true;

  services.xserver.layout = "us";

  ################################
  ## Security
  ################################
  security.polkit.enable = true;
  services.pcscd.enable = true; # need for working with yubikey

  ################################
  ## ZFS
  ################################
  services.zfs.autoScrub.enable = true;
  services.zfs.trim.enable = true;
  boot.extraModprobeConfig = ''
    options zfs l2arc_rebuild_enabled=1 l2arc_headroom=0 l2arc_write_max=${builtins.toString (100 * 1024 * 1024)} l2arc_write_boost=${builtins.toString (1024 * 1024 * 1024)} l2arc_noprefetch=0
  '';
  services.zfs.zed = {
    settings = {
       # TODO: Make secret
      ZED_PUSHOVER_TOKEN = "REDACTED_PUSHOVER_TOKEN";
      ZED_PUSHOVER_USER = "ubeszsjqr12emacca1wgqgca5g3yau";
    };
  };
  boot.zfs.requestEncryptionCredentials = [
    "primary/nixos"
    "secondary/encrypted"
  ];

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
    extraGroups = [ "wheel" "scanner" "lp" "corectrl" "plugdev" ];
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
    alacritty
    kitty
    unstable.neovim-unwrapped

    ################################
    ##  Virtualization Utilities
    ################################
    slirp4netns
    # TODO: remove when native overlay fs is supported in zfs 2.2
    # See: https://github.com/openzfs/zfs/issues/8648
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
    sbctl # secure boot key manager

    ################################
    ##  Parsers
    ################################
    jq # JSON parser
    yq # YAML parser
    envsubst # Environment variable interpolation

    ################################
    ##  General Tooling
    ################################
    unzip # ZIP archive management
    rsync # Local file syncronization
    python310 # Scripting language
    pv # Stream monitoring
    eza # "Better" ls written in rust
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
    gtk3 # toolkit for creating guis
    webkitgtk # webkit rendering engine
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
    btop # Better interactive process monitoring
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
    libusb1 # for programming usb devices

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
    settings = {
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
  system.autoUpgrade = {
    enable = true;
    allowReboot = false;
    dates = "04:00";
    persistent = true;
  };

  # Configure automatic package garbage collection
  nix.gc = {
    automatic = true;
    dates = "05:00";
    persistent = true;
    options = "-d"; # ensures old profiles are cleaned
  };


  # Ensure the cpu doesn't get blasted
  nix.daemonCPUSchedPolicy = "idle";
  nix.settings.max-jobs = 16;

  # Enable flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}

