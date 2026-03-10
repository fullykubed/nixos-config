{ nixpkgs-unstable, ... }:
{
  nixpkgs.overlays = [
    (final: prev: {
      # ImageMagick 7.1.2-15 - fixes 31 CVEs (7 High, 21 Medium, 3 previously backported)
      # Includes CVE-2026-23876, CVE-2026-22770, CVE-2026-23874 plus 28 new CVEs
      # disclosed Feb 24, 2026 and fixed upstream in 7.1.2-15
      # NOTE: Override to use our patched openexr (eliminates openexr 3.3.5 CVEs)
      imagemagick =
        (nixpkgs-unstable.imagemagick.override {
          inherit (final) openexr;
          libjxl = nixpkgs-unstable.libjxl.override { inherit (final) openexr; };
        }).overrideAttrs
          (_old: {
            version = "7.1.2-15";
            src = prev.fetchFromGitHub {
              owner = "ImageMagick";
              repo = "ImageMagick";
              rev = "7.1.2-15";
              hash = "sha256-qL7CYq+aGCB3ZLgIcSBy2Dw69g0F68xGXxrE7xJhdNc=";
            };
          });
    })
  ];
}
