_: {
  nixpkgs.overlays = [
    (_final: prev: {
      # CVE-2025-64524: Fix heap-buffer-overflow in cups-filters rastertopclx
      # See: https://nvd.nist.gov/vuln/detail/CVE-2025-64524
      cups-filters = prev.cups-filters.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          ./CVE-2025-64524.patch
        ];
      });
    })
  ];
}
