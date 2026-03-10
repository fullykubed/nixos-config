_: {
  nixpkgs.overlays = [
    (_final: prev: {
      # Firefox: Disable LTO to prevent OOM kill (exit 137) during libxul.so linking.
      # With full cross-language LTO enabled (the default), LLD consumes 10+ GB linking
      # libxul.so. buildMozillaMach has no knob for LTO partitions or linker thread count -
      # it's binary: --enable-lto=cross,full or off. Disabling LTO avoids the OOM with
      # negligible real-world performance impact (PGO provides most of the optimization).
      firefox-unwrapped = prev.firefox-unwrapped.override {
        ltoSupport = false;
      };
    })
  ];
}
