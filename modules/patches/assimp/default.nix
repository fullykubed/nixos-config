_: {
  nixpkgs.overlays = [
    (_final: prev: {
      # Assimp CVE-2025-11277 (CVSS 5.3 Medium): Heap buffer overflow in Q3DLoader
      # Integer overflow when multiplying texture dimensions -> potential RCE via malicious Q3D file
      # Pulled in by: qt3d (Qt 3D graphics module)
      # See: https://nvd.nist.gov/vuln/detail/CVE-2025-11277
      assimp = prev.assimp.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          ./CVE-2025-11277.patch
          ./assimp-fix-uninitialized-shadingMode.patch
        ];
      });
    })
  ];
}
