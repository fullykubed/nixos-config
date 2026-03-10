{ nixpkgs-unstable, ... }:
{
  nixpkgs.overlays = [
    (_final: _prev: {
      # FFmpeg 7.1.3 from unstable + 3 backported CVE patches
      # Bundled by: Firefox, VLC (media playback)
      # Version bump fixes 9 CVEs over 7.1.2:
      #   CVE-2023-51791 (7.8 High): heap overflow in jpegxl_parser
      #   CVE-2023-51793 (7.8 High): heap overflow in vf_weave
      #   CVE-2023-51794 (7.8 High): heap overflow in af_stereowiden
      #   CVE-2023-51795 (8.0 High): heap overflow in avf_showspectrum
      #   CVE-2023-51796 (3.6 Low):  heap overflow in f_reverse
      #   CVE-2023-51797 (6.7 Med):  heap overflow in avf_showwaves
      #   CVE-2023-51798 (7.8 High): heap overflow in vf_minterpolate
      #   CVE-2025-10256 (5.3 Med):  NULL deref in af_firequalizer
      #   CVE-2025-12343 (3.3 Low):  double-free in dnn_backend_tf
      # Backported patch fixes 1 more CVE (not backported upstream to 7.1.x):
      #   CVE-2025-22921 (6.5 Med): segfault in jpeg2000dec
      ffmpeg_7 = nixpkgs-unstable.ffmpeg_7.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          ./CVE-2025-22921.patch
        ];
      });
      ffmpeg_7-full = nixpkgs-unstable.ffmpeg_7-full.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          ./CVE-2025-22921.patch
        ];
      });
      ffmpeg_7-headless = nixpkgs-unstable.ffmpeg_7-headless.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          ./CVE-2025-22921.patch
        ];
      });
    })
  ];
}
