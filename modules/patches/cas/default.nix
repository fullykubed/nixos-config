# Workaround for NixOS/nix#15003: closureInfo can't parse CA placeholder
# paths with subpath suffixes (e.g. "<placeholder>/lib").
#
# stage-1.nix passes entries like:
#   { object = "${modulesClosure}/lib"; symlink = "/lib"; }
#
# When any transitive dependency is content-addressed, the subpath string
# resolves to "<ca-placeholder>/lib" in the .drv — which the daemon can't
# parse. makeInitrd already supports a suffix field that keeps subpaths out
# of closureInfo:
#   objects  = map (x: x.object) contents;            -> feeds closureInfo
#   suffices = map (x: x.suffix or "none") contents;  -> shell script only
#   ln -s $object$suffix root/$symlink                -> appended at symlink time
#
# This overlay wraps makeInitrd to auto-split subpath entries into
# object + suffix, so closureInfo only receives bare store paths.
_:
let
  overlay = _final: prev: {
    # buildEnv creates symlink trees (e.g. perl.withPackages, python.buildEnv).
    # CA output ingestion fails on these because the daemon can't recreate the
    # symlink structure at the content-addressed path. Symlink trees are unique
    # per environment anyway, so CA deduplication provides no benefit.
    buildEnv = args: (prev.buildEnv args).overrideAttrs { __contentAddressed = false; };

    makeInitrd =
      args:
      let
        fixEntry =
          entry:
          if entry ? suffix then
            entry
          else
            let
              str = toString entry.object;
              # Match store paths with subpaths in either format:
              # - Normal:         /nix/store/<32-char-hash>-<name>/<subpath>
              # - CA placeholder: /<52-char-hash>/<subpath>
              # builtins.match does full-string matching; returns null on no match.
              # The first capture group is the base store path, the second is the subpath.
              matched = builtins.match "(/nix/store/[a-z0-9]{32}-[^/]+|/[a-z0-9]{52})(/.+)" str;
            in
            if matched == null then
              entry
            else
              let
                baseLen = builtins.stringLength (builtins.elemAt matched 0);
                len = builtins.stringLength str;
              in
              entry
              // {
                # builtins.substring preserves string context (derivation refs),
                # unlike builtins.match which discards it.
                object = builtins.substring 0 baseLen str;
                suffix = builtins.substring baseLen (len - baseLen) str;
              };
      in
      prev.makeInitrd (
        args
        // {
          contents = map fixEntry (args.contents or [ ]);
        }
      );
  };
in
{
  nixpkgs.overlays = [ overlay ];
  nixpkgs-unstable.overlays = [ overlay ];

  # nixpkgs-unstable CA is controlled in lib/nixpkgs-unstable.nix
  nixpkgs.config.contentAddressedByDefault = true;
}
