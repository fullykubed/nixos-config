# Mirror grub's savannah dependencies through GitHub to avoid rate limiting.
#
# grub fetches its source, gnulib, and ~88 CVE patches from
# git.savannah.gnu.org, which aggressively rate-limits and frequently
# times out. GitHub mirrors of the same repos have identical commit
# SHAs, and fetchpatch normalizes away header differences, so hashes
# are unchanged.
{ lib, ... }:
let
  savannahPatchPrefix = "https://git.savannah.gnu.org/cgit/grub.git/patch/?id=";
  githubPatchPrefix = "https://github.com/rhboot/grub2/commit/";

  overlay = _final: prev: {
    grub2 = prev.grub2.override {
      # Rewrite fetchpatch URLs from savannah cgit → GitHub .diff
      fetchpatch =
        args:
        prev.fetchpatch (
          args
          // {
            url =
              if lib.hasPrefix savannahPatchPrefix args.url then
                githubPatchPrefix + lib.removePrefix savannahPatchPrefix args.url + ".diff"
              else
                args.url;
          }
        );

      # Rewrite fetchgit URLs for grub source and vendored gnulib
      fetchgit =
        args:
        prev.fetchgit (
          args
          // {
            url =
              {
                "https://git.savannah.gnu.org/git/grub.git" = "https://github.com/rhboot/grub2.git";
                "https://git.savannah.gnu.org/git/gnulib.git" = "https://github.com/coreutils/gnulib.git";
              }
              .${args.url} or args.url;
          }
        );
    };
  };
in
{
  nixpkgs.overlays = [ overlay ];
  nixpkgs-unstable.overlays = [ overlay ];
}
