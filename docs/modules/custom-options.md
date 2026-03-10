# Custom Options

Modules can define options that device files set. This is the primary way to handle per-machine differences.

## Example

```nix
{ config, lib, ... }:
{
  options.gpuVendor = lib.mkOption {
    type = lib.types.nullOr (lib.types.enum [ "amd" ]);
    default = null;
    description = "Discrete GPU vendor for driver configuration.";
  };

  config = lib.mkIf (config.gpuVendor == "amd") {
    services.xserver.videoDrivers = [ "amdgpu" ];
  };
}
```

Device files then set the option:

```nix
# devices/tower.nix
{
  gpuVendor = "amd";
}
```

Shared options like `username`, `monitors`, `cpuVendor`, and `cpuCount` are defined in `modules/common/global-options/`.
