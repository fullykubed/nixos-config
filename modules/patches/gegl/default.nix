_: {
  nixpkgs.overlays = [
    (final: prev: {
      # GEGL: Rebuild with OpenEXR 3.4.4 instead of legacy openexr_2 (2.5.10)
      # This eliminates openexr_2 from the system, fixing 11 CVEs including:
      #   CVE-2023-5841 (9.1 Crit): Heap buffer overflow in deep scanline parsing
      #   CVE-2021-23169 (8.8 High): Heap buffer overflow -> RCE
      #   CVE-2025-12495 (7.8 High): Heap buffer overflow RCE via EXR parsing
      # gegl 0.4.48+ supports OpenEXR 3.x (fixed: https://gitlab.gnome.org/GNOME/gegl/-/issues/284)
      # NOTE: gegl expects openexr_2 parameter name; map our modern openexr to it
      gegl = prev.gegl.override {
        openexr_2 = final.openexr;
      };
    })
  ];
}
