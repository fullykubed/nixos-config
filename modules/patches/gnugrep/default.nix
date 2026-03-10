# Replace GNU grep with ugrep in every derivation
#
# ugrep is a drop-in replacement for grep with better performance and
# extended features. Since gnugrep is in stdenv's initialPath, overriding
# it here propagates to all derivations.
#
# Wrapper scripts pass the correct flags since NixOS doesn't preserve
# argv[0] through symlinks for auto-detection.
# Per https://github.com/Genivia/ugrep#equivalence-to-gnubsd-grep:
#   grep   = ugrep -G -Y -. --sort
#   egrep  = ugrep -E -Y -. --sort
#   fgrep  = ugrep -F -Y -. --sort
# -Y: match empty patterns  -.: search hidden files  --sort: sort by pathname
_:
let
  overlay = final: prev: {
    gnugrep = prev.gnugrep.overrideAttrs (old: {
      postInstall =
        let
          ugrep = "${final.ugrep}/bin/ugrep";
          common = "-Y -. --sort";
          wrapper = name: flags: ''
            rm -f $out/bin/${name}
            cat > $out/bin/${name} <<'WRAPPER'
            #!/bin/sh
            exec ${ugrep} ${flags} ${common} "$@"
            WRAPPER
            chmod +x $out/bin/${name}
          '';
        in
        (old.postInstall or "") + wrapper "grep" "-G" + wrapper "egrep" "-E" + wrapper "fgrep" "-F";
    });
  };
in
{
  nixpkgs.overlays = [ overlay ];
  nixpkgs-unstable.overlays = [ overlay ];
}
