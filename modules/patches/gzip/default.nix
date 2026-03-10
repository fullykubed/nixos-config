# Replace zgrep/zegrep/zfgrep with ugrep wrappers
#
# gzip ships zgrep, zegrep, and zfgrep. This replaces them with ugrep
# wrappers using -z for compressed file support, matching the gnugrep
# overlay that replaces grep/egrep/fgrep.
# Per https://github.com/Genivia/ugrep#equivalence-to-gnubsd-grep:
#   zgrep  = ugrep -z -G -Y -. --sort
#   zegrep = ugrep -z -E -Y -. --sort
#   zfgrep = ugrep -z -F -Y -. --sort
_:
let
  overlay = final: prev: {
    gzip = prev.gzip.overrideAttrs (old: {
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
        (old.postInstall or "")
        + wrapper "zgrep" "-z -G"
        + wrapper "zegrep" "-z -E"
        + wrapper "zfgrep" "-z -F";
    });
  };
in
{
  nixpkgs.overlays = [ overlay ];
  nixpkgs-unstable.overlays = [ overlay ];
}
