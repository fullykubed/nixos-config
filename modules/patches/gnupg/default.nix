_: {
  nixpkgs.overlays = [
    (_final: prev: {
      # GnuPG security patches (both fixed in 2.4.9)
      # CVE-2025-68973 (CVSS 7.8 High): Memory corruption in armor parser
      #   Out-of-bounds write in armor_filter (g10/armor.c)
      #   See: https://nvd.nist.gov/vuln/detail/CVE-2025-68973
      # CVE-2025-68972 (CVSS 5.9 Med): Formfeed signature verification bypass
      #   Adversary can append unverified content after signed material
      #   See: https://nvd.nist.gov/vuln/detail/CVE-2025-68972
      gnupg = prev.gnupg.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          ./CVE-2025-68973.patch
          ./CVE-2025-68972.patch
        ];
      });
    })
  ];
}
