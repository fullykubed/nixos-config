{ mkDiskImage, niks3 }:
mkDiskImage {
  additionalSpace = "4G";
  modules = [
    niks3.nixosModules.default
    ./image.nix
  ];
}
