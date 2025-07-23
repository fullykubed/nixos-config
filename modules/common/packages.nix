# These are miscellenous pacakges that don't need any configuration
# beyond the initial installation

{ config, pkgs, ... }:
{
  nixpkgs.config.allowUnfree = true;
  environment.systemPackages = with pkgs; [
    wget # TODO: Remove from scripts

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
    barrier

    ################################
    ##  Doc Editors
    ################################
    libreoffice
    unstable.drawio # TODO: Need to edit desktop config to start with --disable-gpu

    ################################
    ##  Parsers
    ################################
    jq # JSON parser
    yq # YAML parser

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

    ################################
    ##  Process Isolation + Securtiy
    ################################
    bubblewrap # Unprivileged sandboxing tool
    wireguard-tools # User-space tools for interfacing with wireguard kernel module
    openssl_3_0 # Certificate generation
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
    glxinfo # CLI for debugging some issues with GLX, powers X graphics (older)
    egl-wayland # CLI for debugging some issues with the EGLStreams; EGLStreams powers Wayland desktop (newer)

    ################################
    ##  Low-Level Disk Tooling
    ################################
    smartmontools # SMART cli for disk health checking
    hdparm # Interfacing with hard didks
    nvme-cli # Interfacing with nvme disks

    ################################
    ##  System Debugging + Monitoring
    ################################
    sysz # TUI for systemd
    lnav # Structured log file navigator
    dmidecode # Reads info about connected devices from MOBO through SMBIOS/DMI
    btop # Better interactive process monitoring
    lshw # Alternative way to query hardware
    lm_sensors # For reading hardware sensors
    mission-center # For displaying hardware sensors graphically
    sysstat # Performance monitoring tools (e.g., iostat, pidstat)
    fio # Testing file system speed

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

    ################################
    ##  Password and secrets management
    ################################
    keepassxc # Wayland (thank god)
    gnupg # GPL OpenPGP implementation
    rage # age implementation in rust

    ################################
    ##  Kubernetes
    ################################
    kubectl # Kubernetes cli
    kubectx # Kubernetes context switcher
    k9s # TUI for k8s

    ################################
    ##  Recording and Streaming
    ################################
    obs-studio # Recording + streaming; unstable for wayland supported version

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
    ##  Finance
    ################################
    homebank

    ################################
    ##  Fileharing
    ################################
    qbittorrent # Bittorrent client
    croc # CLI for secure p2p file sharing

    ################################
    ##  Media Players
    ################################
    spotify # X11 (electron)

    ################################
    ##  Gaming
    ################################
    lutris
    gamemode
    gamescope

    ################################
    ## Databases
    ################################
    sqlite

  ];
}
