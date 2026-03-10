{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.gpuVendor = lib.mkOption {
    type = lib.types.nullOr (lib.types.enum [ "amd" ]);
    default = null;
    description = "Discrete GPU vendor for driver configuration. Null means no discrete GPU.";
  };

  config = lib.mkIf (config.gpuVendor == "amd") {
    services.xserver.videoDrivers = [ "amdgpu" ];
    programs.corectrl.enable = true;
    environment.systemPackages = with pkgs; [
      radeontop # GPU monitoring
    ];
  };
}
