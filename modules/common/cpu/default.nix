{ config, lib, ... }:
{
  options = {
    cpuVendor = lib.mkOption {
      type = lib.types.enum [
        "amd"
        "intel"
      ];
      description = "CPU vendor for microcode updates and KVM support.";
    };

    cpuCount = lib.mkOption {
      type = lib.types.int;
      description = "The number of CPU cores on this system.";
    };
  };

  config = lib.mkMerge [
    {
      hardware.enableRedistributableFirmware = true;

      # Motherboard sensor modules (vendor-independent)
      environment.etc."sysconfig/lm_sensors".text = lib.mkDefault ''
        HWMON_MODULES="${
          if config.cpuVendor == "amd" then "k10temp" else "coretemp"
        } nct6775 i2c-piix4 lm92"
      '';
    }
    (lib.mkIf (config.cpuVendor == "amd") {
      boot.kernelModules = [ "kvm-amd" ];
      hardware.cpu.amd.updateMicrocode = true;
    })
    (lib.mkIf (config.cpuVendor == "intel") {
      boot.kernelModules = [ "kvm-intel" ];
      hardware.cpu.intel.updateMicrocode = true;
    })
    (lib.mkIf (
      config.deviceType == "desktop"
      || config.deviceType == "server"
      || config.deviceType == "remote-builder"
    ) { powerManagement.cpuFreqGovernor = "performance"; })
    # ── Remote-builder power throttling ─────────────────────────────────────
    # Disable all power management features that reduce sustained build throughput.
    # Deep C-states add wake latency between build tasks; AMD P-State active mode
    # keeps the boost clock engaged continuously.
    (lib.mkIf (config.deviceType == "remote-builder") {
      boot.kernelParams = [
        "processor.max_cstate=1" # Prevent deep C-states (latency on wake)
        "amd_pstate=active" # AMD P-State driver in active mode (full boost)
      ];
      # Disable thermald if present — let the hardware handle thermal limits
      # directly rather than throttling from userspace.
      services.thermald.enable = lib.mkForce false;
    })
    (lib.mkIf (config.deviceType == "laptop") {
      services.auto-cpufreq = {
        enable = true;
        settings = {
          charger = {
            governor = "performance";
            turbo = "auto";
          };
          battery = {
            governor = "powersave";
            turbo = "never";
          };
        };
      };
    })
  ];
}
