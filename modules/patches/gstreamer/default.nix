# GStreamer 1.26.11 security update from 1.26.5
# Fixes 10 remote code execution CVEs (all ZDI-disclosed 2026-03-06):
#
# gst-plugins-good:
#   CVE-2026-3083 (8.8 High): rtpqdm2depay OOB write via X-QDM RTP payloads (network-accessible)
#   CVE-2026-3085 (8.8 High): rtpqdm2depay heap overflow via X-QDM RTP payloads (network-accessible)
# gst-plugins-bad:
#   CVE-2026-2923 (7.8 High): DVB subtitles OOB write via unchecked coordinates
#   CVE-2026-3081 (7.8 High): H.266 codec parser stack overflow in decoding units
#   CVE-2026-3082 (7.8 High): JPEG parser heap overflow in Huffman tables
#   CVE-2026-3084 (7.8 High): H.266 codec parser integer underflow in picture partitions
#   CVE-2026-3086 (7.8 High): H.266 codec parser OOB write in APS units
# gst-plugins-ugly:
#   CVE-2026-2920 (7.8 High): ASF demuxer heap overflow via stream headers
#   CVE-2026-2922 (7.8 High): RealMedia demuxer OOB write via video packets
# gst-plugins-base:
#   CVE-2026-2921 (7.8 High): RIFF palette integer overflow via AVI files
#
# Upstream: https://gstreamer.freedesktop.org/releases/1.26/#1.26.11
# nixpkgs PR: https://github.com/NixOS/nixpkgs/pull/500412 (not yet merged)
_:
let
  overlay = _final: prev: {
    gst_all_1 = prev.gst_all_1.overrideScope (
      _gstFinal: gstPrev:
      let
        bumpSrc =
          pname: hash:
          prev.fetchurl {
            url = "https://gstreamer.freedesktop.org/src/${pname}/${pname}-1.26.11.tar.xz";
            inherit hash;
          };
        bump =
          pname: hash:
          gstPrev.${pname}.overrideAttrs {
            version = "1.26.11";
            src = bumpSrc pname hash;
          };
      in
      {
        gstreamer = bump "gstreamer" "sha256-LgvRktBDjqYGpvdqlcjhZUIWdlb/7Cwrw6r27gg3+/Y=";
        gst-plugins-base = bump "gst-plugins-base" "sha256-/FD4hdQfXQQHzgh27HI12ee4LUjbL0vHLF8kSkrHkmM=";
        gst-plugins-good = bump "gst-plugins-good" "sha256-AB3rCHbV10PNNEir90onrew/2FABL8sbAJlIYb1sEUU=";
        gst-plugins-bad = bump "gst-plugins-bad" "sha256-EQ+4J5Xw5Wmx4nsSq5aZ01x3YuH/TblTNdasjRRCrz0=";
        gst-plugins-ugly = bump "gst-plugins-ugly" "sha256-v5yfcu43SCXP1DhowoW8sBcA3yWEBp51169FX+SCRPg=";
        gst-libav = bump "gst-libav" "sha256-m7PSaB7w3pLRsanZVRhiNu4i5k83Lbm/wNIuLQ3xmGU=";
        gst-editing-services = bump "gst-editing-services" "sha256-o26HkAtErBYIYS8tYW/AMvnX2SAyfE0jGv+2/pNJcU0=";
        gst-rtsp-server = bump "gst-rtsp-server" "sha256-th1DBNjOqqoboTn7HOk18E8ac9fhgkPAoFsvsEMFQG8=";
        gstreamer-vaapi = bump "gstreamer-vaapi" "sha256-8S+TAnPHodPg1/hblP+dE3nRYqzMky6Mo9OJk+0n/Kw=";

        # gst-devtools needs special handling: cargoDeps hash update + patch removal
        gst-devtools = gstPrev.gst-devtools.overrideAttrs (
          _old:
          let
            newSrc = bumpSrc "gst-devtools" "sha256-Vl9IU4jJSYr+v3gAQYPN/xATEhEoZBqlbtql6pRBK+I=";
          in
          {
            version = "1.26.11";
            src = newSrc;
            patches = [ ];
            cargoDeps = prev.rustPlatform.fetchCargoVendor {
              src = newSrc;
              hash = "sha256-sqN1IBkbrT3pQqUQKU2pr8G1t4kNMKk0NR7NH7dTvAE=";
            };
          }
        );
      }
    );
  };
in
{
  nixpkgs.overlays = [ overlay ];
  nixpkgs-unstable.overlays = [ overlay ];
}
