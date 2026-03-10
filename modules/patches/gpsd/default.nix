_: {
  nixpkgs.overlays = [
    (_final: prev: {
      # gpsd security patches
      # CVE-2025-67268: Fix heap-based buffer overflow in NMEA2000 driver
      #   Critical (CVSS 9.8): Remote code execution via malicious GPS packets
      #   See: https://nvd.nist.gov/vuln/detail/CVE-2025-67268
      # CVE-2025-67269: Fix integer underflow in NAVCOM packet parsing
      #   High (CVSS 7.5): DoS via CPU exhaustion from malicious packets
      #   See: https://nvd.nist.gov/vuln/detail/CVE-2025-67269
      gpsd = prev.gpsd.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          ./CVE-2025-67268.patch
          ./CVE-2025-67269.patch
        ];
      });
    })
  ];
}
