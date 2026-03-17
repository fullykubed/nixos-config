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
    (lib.mkIf (config.deviceType == "desktop" || config.deviceType == "server") {
      powerManagement.cpuFreqGovernor = "performance";
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
