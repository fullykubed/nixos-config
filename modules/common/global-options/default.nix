{
  config,
  lib,
  ...
}:
let
  # Base microarchitecture values accepted by GCC 14 / Clang 18
  marchValues = [
    # Generic x86-64 levels
    "x86-64"
    "x86-64-v2"
    "x86-64-v3"
    "x86-64-v4"
    # AMD
    "k8"
    "k8-sse3"
    "amdfam10"
    "bdver1"
    "bdver2"
    "bdver3"
    "bdver4"
    "btver1"
    "btver2"
    "znver1"
    "znver2"
    "znver3"
    "znver4"
    "znver5"
    # Intel
    "core2"
    "nehalem"
    "westmere"
    "sandybridge"
    "ivybridge"
    "haswell"
    "broadwell"
    "skylake"
    "skylake-avx512"
    "cascadelake"
    "cooperlake"
    "icelake-client"
    "icelake-server"
    "tigerlake"
    "sapphirerapids"
    "rocketlake"
    "alderlake"
    "raptorlake"
    "meteorlake"
    "arrowlake"
    "arrowlake-s"
    "lunarlake"
    "pantherlake"
    "clearwaterforest"
    # Atom
    "bonnell"
    "silvermont"
    "goldmont"
    "goldmont-plus"
    "tremont"
    "gracemont"
    "crestmont"
    "sierraforest"
    # Special
    "native"
  ];

  # x86-64-v* levels are not valid for -mtune; add "generic" instead
  mtuneValues = builtins.filter (v: !(lib.hasPrefix "x86-64-v" v) && v != "x86-64") marchValues ++ [
    "generic"
  ];
in
{
  options = with lib; {
    username = mkOption {
      type = types.str;
      description = "The primary user's username on the system.";
    };

    homeDir = mkOption {
      default = "/home/${config.username}";
      type = types.str;
      description = "The primary user's username on the system.";
    };

    deviceType = mkOption {
      type = types.enum [
        "laptop"
        "desktop"
        "server"
        "remote-builder"
      ];
      description = "The type of device — controls power management and other hardware-class defaults.";
    };

    firmwareType = mkOption {
      type = types.enum [
        "standard"
        "coreboot"
      ];
      default = "standard";
      description = "Firmware type — 'coreboot' enables fwupd and flashrom for coreboot-based firmware updates.";
    };

    cpuArch = mkOption {
      type = types.nullOr (types.enum marchValues);
      default = null;
      description = "CPU microarchitecture for -march. Null means no flag is injected.";
    };

    cpuTune = mkOption {
      type = types.nullOr (types.enum mtuneValues);
      default = null;
      description = "CPU tuning target for -mtune. Null means no flag is injected.";
    };

    monitors = mkOption {
      default = { };
      type = types.attrsOf (
        types.submodule {
          options = {
            mode = mkOption {
              type = types.str;
              description = "Display mode (e.g., '3840x2160')";
            };
            pos = mkOption {
              type = types.str;
              description = "Position (e.g., '0 0', '3840 0')";
            };
            num = mkOption {
              type = types.int;
              description = "Monitor number (1=left, 2=middle, 3=right)";
            };
            scale = mkOption {
              type = types.number;
              default = 1;
              description = "Output scale factor (e.g., 1, 1.5, 2)";
            };
            notifications = mkOption {
              type = types.bool;
              default = false;
              description = "Whether this monitor should display notifications";
            };
          };
        }
      );
      description = "Monitor configuration where keys are output names and values contain mode, position, and number.";
    };

    systemRam = lib.mkOption {
      type = lib.types.int;
      description = "Physical RAM in GB — used for swap partition sizing and zswap pool configuration.";
    };

    enableZswap = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable zswap (compressed swap cache with encrypted disk backing).";
    };

    builderHousekeepingCpus = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "CPU range for kernel housekeeping (IRQs, RCU, timers). Should align with CCD boundaries to avoid L3 cache contention. Example: '0-15' (one full CCD on Zen 5 Threadripper). Only used when deviceType == 'remote-builder'.";
    };

    builderIsolatedCpus = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "CPU range to isolate for build work (no housekeeping). Should align with CCD boundaries. Example: '16-127' (CCDs 1-7 on Zen 5 Threadripper). Only used when deviceType == 'remote-builder'.";
    };
  };
}
