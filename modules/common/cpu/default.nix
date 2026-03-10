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
    { hardware.enableRedistributableFirmware = true; }
    (lib.mkIf (config.cpuVendor == "amd") {
      boot.kernelModules = [ "kvm-amd" ];
      hardware.cpu.amd.updateMicrocode = true;
    })
    (lib.mkIf (config.cpuVendor == "intel") {
      boot.kernelModules = [ "kvm-intel" ];
      hardware.cpu.intel.updateMicrocode = true;
    })
  ];
}
