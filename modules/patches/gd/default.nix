_: {
  nixpkgs.overlays = [
    (final: prev: {
      # gd: Force rebuild with fixed libavif 1.3.0
      # CVE-2025-48174 (4.5-9.1): Integer overflow in makeRoom (stream.c)
      # CVE-2025-48175 (4.5-6.5): Integer overflows in avifImageRGBToYUV (reformat.c)
      # Dependency chain: SwayNotificationCenter -> gvfs -> libgphoto2 -> gd -> libavif
      gd = prev.gd.override {
        inherit (final) libavif;
      };
    })
  ];
}
