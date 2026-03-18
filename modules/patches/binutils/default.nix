_: {
  nixpkgs.overlays = [
    (_final: prev: {
      # GNU Binutils 2.44 security patches
      # stdenv reference checks disabled to allow bootstrap patching
      # CVE-2025-1153 (CVSS 3.1 Low): Memory corruption in bfd_set_format
      # CVE-2025-3198 (CVSS 3.3 Low): Memory leak in display_info (objdump)
      # CVE-2025-5244 (CVSS 5.3 Med): Memory corruption in elf_gc_sweep (ld)
      # CVE-2025-5245 (CVSS 5.3 Med): Memory corruption in debug_type_samep (objdump)
      # CVE-2025-8224 (CVSS 3.3 Low): Null pointer dereference in bfd_elf_get_str_section
      # CVE-2025-8225 (CVSS 3.3 Low): Memory leak in DWARF handler
      binutils-unwrapped = prev.binutils-unwrapped.overrideAttrs (old: {
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ prev.flex ];
        patches = (old.patches or [ ]) ++ [
          ./CVE-2025-1153.patch
          ./CVE-2025-3198.patch
          ./CVE-2025-5244.patch
          ./CVE-2025-5245.patch
          ./CVE-2025-8224.patch
          ./CVE-2025-8225.patch
        ];
      });
    })
  ];
}
