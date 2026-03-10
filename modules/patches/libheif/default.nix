_: {
  nixpkgs.overlays = [
    (final: prev: {
      # libheif: HEIF/AVIF image format library
      # Must use our nasm-based libaom, otherwise pulls in yasm via:
      # imagemagick -> libheif -> libaom -> yasm
      libheif = prev.libheif.override {
        inherit (final) libaom;
      };
    })
  ];
}
