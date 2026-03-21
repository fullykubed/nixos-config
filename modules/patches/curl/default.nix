# curl 8.18.0: 4 CVEs fixed in 8.19.0 (2026-03-11 security advisory)
#
# CVE-2026-1965 (Medium): Bad reuse of HTTP Negotiate connection
# See: https://curl.se/docs/CVE-2026-1965.html
#
# CVE-2026-3783 (Medium): Token leak with redirect and netrc
# See: https://curl.se/docs/CVE-2026-3783.html
#
# CVE-2026-3784 (Low): Wrong proxy connection reuse with credentials
# See: https://curl.se/docs/CVE-2026-3784.html
#
# CVE-2026-3805 (Medium): Use-after-free in SMB connection reuse
# See: https://curl.se/docs/CVE-2026-3805.html
_: {
  nixpkgs.overlays = [
    (_final: prev: {
      curl = prev.curl.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          ./CVE-2026-1965.patch
          ./CVE-2026-1965-2.patch
          ./CVE-2026-3783.patch
          ./CVE-2026-3784.patch
          ./CVE-2026-3805.patch
        ];
      });
    })
  ];
}
