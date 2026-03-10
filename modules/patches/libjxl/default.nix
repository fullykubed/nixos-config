_: {
  nixpkgs.overlays = [
    (final: prev: {
      # libjxl: Force rebuild with patched openexr to eliminate openexr-3.3.5
      # Without this, libjxl links against the default nixpkgs openexr-3.3.5 which has:
      #   CVE-2025-12495 (7.8 High): Heap buffer overflow -> RCE
      #   CVE-2025-12839 (7.8 High): Heap buffer overflow -> RCE
      #   CVE-2025-12840 (7.8 High): Heap buffer overflow -> RCE
      #   CVE-2025-64181 (7.5 High): Uninitialized memory -> DoS
      libjxl = prev.libjxl.override {
        inherit (final) openexr;
      };
    })
  ];
}
