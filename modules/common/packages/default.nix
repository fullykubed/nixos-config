# These are miscellenous pacakges that don't need any configuration
# beyond the initial installation

{ pkgs, ... }:
{
  nixpkgs.config.allowUnfree = true;
  environment.systemPackages = with pkgs; [
    wget

    ################################
    ##  Nix Debugging Utilities
    ################################
    cntr

    ################################
    ##  Programming Languages
    ################################
    go
    cargo
    luajitPackages.luarocks
    python314
    uv # python pacakge manager
    jdk
    powershell
    nodejs_24
    bun

    ################################
    ##  KVM
    ################################
    deskflow

    ################################
    ##  Parsers
    ################################
    jq # JSON parser
    yq # YAML parser
    jaq # Fast JSON/YAML processor (jq-compatible, Rust)

    ################################
    ##  Search
    ################################
    bfs # Breadth-first find (drop-in replacement for find)

    ################################
    ##  Scriping Tools
    ################################
    unzip # ZIP archive management
    cryptsetup # Working with dmcrypt
    parallel # Executing commands in parallel
    envsubst # Environment variable interpolation
    rsync # Local file syncronization
    parallel # Executing commands in parallel
    envsubst # Environment variable interpolation
    glow # markdown renderer for the CLI
    unixtools.xxd # Hex dump utility
    unixtools.quota # Disk quota reporting

    ################################
    ##  Process Isolation + Securtiy
    ################################
    bubblewrap # Unprivileged sandboxing tool
    wireguard-tools # User-space tools for interfacing with wireguard kernel module
    openssl_3 # Certificate generation
    xorg.xeyes # For checking if an app is running in x compat mode
    su # For UID mapping

    ################################
    ##  Build Tools
    ################################
    gnumake
    gcc
    fakeroot
    ncurses
    flex
    bison
    pkg-config

    ################################
    ##  Word Lists
    ################################
    aspell
    aspellDicts.en

    ################################
    ##  Low-Level Graphics Tooling
    ################################
    gtk3 # toolkit for creating guis
    webkitgtk_6_0 # webkit rendering engine
    # Note: See https://mozillagfx.wordpress.com/2021/10/30/switching-the-linux-graphics-stack-from-glx-to-egl/
    mesa-demos # CLI for debugging some issues with GLX, powers X graphics (older)
    egl-wayland # CLI for debugging some issues with the EGLStreams; EGLStreams powers Wayland desktop (newer)

    ################################
    ##  Low-Level Disk Tooling
    ################################
    smartmontools # SMART cli for disk health checking
    hdparm # Interfacing with hard didks
    nvme-cli # Interfacing with nvme disks
    gptfdisk # GPT partition table manipulation (sgdisk)
    parted # Partition editor (partprobe, parted)

    ################################
    ##  System Debugging + Monitoring
    ################################
    sysz # TUI for systemd
    lnav # Structured log file navigator
    dmidecode # Reads info about connected devices from MOBO through SMBIOS/DMI
    lshw # Alternative way to query hardware
    lm_sensors # For reading hardware sensors
    mission-center # For displaying hardware sensors graphically
    sysstat # Performance monitoring tools (e.g., iostat, pidstat)
    fio # Testing file system speed
    pciutils # debugging PCI components
    usbutils # debugging usb devices
    gdb # GNU debugger for debugging crashes and core dumps

    ################################
    ##  Network Tooling
    ################################
    mtr # tracerout
    bind # dns utils

    ################################
    ##  External Devices
    ################################
    android-tools # Working with pixel (and other android devices)
    libusb1 # for programming usb devices

    ################################
    ##  Password and secrets management
    ################################
    gnupg # GPL OpenPGP implementation
    rage # age implementation in rust

    ################################
    ##  Kubernetes
    ################################
    kubectl # Kubernetes cli
    kubectx # Kubernetes context switcher
    k9s # TUI for k8s

    ################################
    ##  Image Editing
    ################################
    imagemagick # For image manipulation
    gimp # Image manipulation
    gifsicle # Image manipulation from the CLI

    ################################
    ##  Video Editing
    ################################
    ffmpeg # Video swiss army knife

    ################################
    ##  File sharing
    ################################
    croc # CLI for secure p2p file sharing

    ################################
    ## Databases
    ################################
    sqlite

  ];
}
