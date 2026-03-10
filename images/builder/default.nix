{ mkDiskImage, niks3 }:
mkDiskImage {
  additionalSpace = "2G";
  modules = [
    ./image.nix
    {
      nixpkgs.overlays = [
        (_: _: {
          niks3-cli = niks3.packages.x86_64-linux.default;
        })
      ];
    }
  ];
}
