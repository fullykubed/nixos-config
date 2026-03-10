_: {
  nixpkgs.overlays = [
    (_final: prev: {
      # GNU Binutils 2.44 security patches
      # stdenv reference checks disabled to allow bootstrap patching
      # CVE-2025-1153 (CVSS 5.9 Med): Memory corruption in bfd_set_format
      # CVE-2025-3198 (CVSS 5.5 Med): Memory leak in display_info (objdump)
      # CVE-2025-8225 (CVSS 3.3 Low): Memory leak in DWARF handler
      binutils-unwrapped = prev.binutils-unwrapped.overrideAttrs (old: {
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ prev.flex ];
        patches = (old.patches or [ ]) ++ [
          ./CVE-2025-1153.patch
          ./CVE-2025-3198.patch
          ./CVE-2025-8225.patch
        ];
      });
    })
  ];
}
