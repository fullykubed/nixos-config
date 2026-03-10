_: {
  nixpkgs.overlays = [
    (final: prev: {
      # libgphoto2: Force rebuild with our patched gd
      # Dependency chain: SwayNotificationCenter -> gvfs -> libgphoto2 -> gd -> libavif
      libgphoto2 = prev.libgphoto2.override {
        inherit (final) gd;
      };
    })
  ];
}
