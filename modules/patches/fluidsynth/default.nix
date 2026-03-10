_: {
  nixpkgs.overlays = [
    (_final: prev: {
      # FluidSynth CVE-2025-68617 (CVSS 7.0 High): Use-after-free in DLS file handling
      # Race condition during DLS file unload can trigger heap-based use-after-free
      # Affects versions 2.5.0-2.5.1, fixed in 2.5.2
      # See: https://nvd.nist.gov/vuln/detail/CVE-2025-68617
      fluidsynth = prev.fluidsynth.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          ./CVE-2025-68617.patch
          ./CVE-2025-68617-2.patch
        ];
      });
    })
  ];
}
