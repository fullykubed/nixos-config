_: {
  nixpkgs.overlays = [
    (final: prev: {
      # libavif: AV1 image format library
      # Must use our nasm-based libaom, otherwise pulls in yasm via:
      # graphviz -> gd -> libavif -> libaom -> yasm
      libavif = prev.libavif.override {
        inherit (final) libaom;
      };
    })
  ];
}
