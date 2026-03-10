_: {
  nixpkgs.overlays = [
    (_final: prev: {
      # libcdio 2.3.0 - Security update from 2.2.0
      # CVE-2024-36600 (CVSS 8.4 High): Buffer overflow in ISO 9660 parsing
      # Allows RCE via crafted ISO image file. Fixed in libcdio 2.3.0.
      # See: https://nvd.nist.gov/vuln/detail/CVE-2024-36600
      libcdio = prev.libcdio.overrideAttrs (_old: rec {
        version = "2.3.0";
        src = prev.fetchFromGitHub {
          owner = "libcdio";
          repo = "libcdio";
          rev = version;
          sha256 = "13zid7gdd82bpll0x8j4aj5jn5p0i1hzsv4hv5hy8111qaqgm61m";
        };
      });
    })
  ];
}
