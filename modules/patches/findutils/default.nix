# Replace GNU find with bfs (breadth-first search) in every derivation
#
# bfs is a drop-in replacement for find that uses breadth-first traversal,
# making it faster for common use cases (shallow matches found sooner).
# Since findutils is in stdenv's initialPath, overriding it here propagates
# to all derivations.
_:
let
  overlay = final: prev: {
    findutils = prev.findutils.overrideAttrs (old: {
      postInstall = (old.postInstall or "") + ''
        rm -f $out/bin/find
        ln -s ${final.bfs}/bin/bfs $out/bin/find
      '';
    });
  };
in
{
  nixpkgs.overlays = [ overlay ];
  nixpkgs-unstable.overlays = [ overlay ];
}
