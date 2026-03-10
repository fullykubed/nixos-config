_: {
  nixpkgs.overlays = [
    (final: prev: {
      # gvfs: Force rebuild with libcdio 2.3.0 to fix CVE-2024-36600
      # Dependency chain: system-path -> gvfs -> libcdio
      gvfs = prev.gvfs.overrideAttrs (old: {
        buildInputs = map (
          input: if (input.pname or "") == "libcdio" then final.libcdio else input
        ) old.buildInputs;
      });
    })
  ];
}
