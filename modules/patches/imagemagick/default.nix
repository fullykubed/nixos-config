{ nixpkgs-unstable, ... }:
{
  nixpkgs.overlays = [
    (final: prev: {
      # ImageMagick 7.1.2-17 - fixes ~36 CVEs vs nixpkgs 7.1.2-13
      #
      # 7.1.2-14/15 (Feb 24, 2026): 25 CVEs including 6 Critical (CVSS 9.0+)
      #   CVE-2026-25968 (9.8), CVE-2026-25971 (9.8), CVE-2026-25986 (9.8),
      #   CVE-2026-25983 (9.8), CVE-2026-25897 (9.8), CVE-2026-25987 (9.1)
      #   + 10 High + 10 Medium severity
      #
      # 7.1.2-16 (Mar 8, 2026): 10 CVEs including 4 High
      #   CVE-2026-28693 (8.1), CVE-2026-28691, CVE-2026-30883 (7.8),
      #   CVE-2026-28494, CVE-2026-28686, CVE-2026-28689, CVE-2026-28687,
      #   CVE-2026-28692, CVE-2026-32259, CVE-2026-31853
      #
      # 7.1.2-17 (Mar 15, 2026): CVE-2026-32636 (5.3) OOB write in NewXMLTree
      #
      # NOTE: Override to use our patched openexr (eliminates openexr 3.3.5 CVEs)
      imagemagick =
        (nixpkgs-unstable.imagemagick.override {
          inherit (final) openexr;
          libjxl = nixpkgs-unstable.libjxl.override { inherit (final) openexr; };
        }).overrideAttrs
          (_old: {
            version = "7.1.2-17";
            src = prev.fetchFromGitHub {
              owner = "ImageMagick";
              repo = "ImageMagick";
              rev = "7.1.2-17";
              hash = "sha256-niqHdNrFMwIr+9560vceRn0LyJPi6DIp6qCn5GlcVjY=";
            };
          });
    })
  ];
}
