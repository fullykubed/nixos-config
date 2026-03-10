_: {
  nixpkgs.overlays = [
    (_final: prev: {
      # MuPDF CVE-2026-25556 (CVSS 7.5 High): Double-free in barcode decoding
      # fz_fill_pixmap_from_display_list() incorrectly drops caller-owned pixmap on error,
      # causing heap corruption when caller also drops it. Affects 1.23.0-1.27.0.
      # Upstream fix: https://cgit.ghostscript.com/cgi-bin/cgit.cgi/mupdf.git/commit/?id=d4743b6092d513321c23c6f7fe5cff87cde043c1
      # See: https://nvd.nist.gov/vuln/detail/CVE-2026-25556
      mupdf = prev.mupdf.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          ./CVE-2026-25556.patch
        ];
      });
    })
  ];
}
