# Alias wrappers so find → bfs and grep → ugrep inside the sandbox.
# Mounted at /opt/find-grep/bin, prepended to PATH.
{ pkgs, ... }:
let
  ugrep = "${pkgs.ugrep}/bin/ugrep";
  common = "-Y -. --sort";

  wrapper = name: flags: ''
    cat > $out/bin/${name} <<'WRAPPER'
    #!/bin/sh
    exec ${ugrep} ${flags} ${common} "$@"
    WRAPPER
    chmod +x $out/bin/${name}
  '';
in
pkgs.runCommand "find-grep-aliases" { } ''
  mkdir -p $out/bin

  cat > $out/bin/find <<'EOF'
  #!/bin/sh
  exec ${pkgs.bfs}/bin/bfs "$@"
  EOF
  chmod +x $out/bin/find

  ${wrapper "grep" "-G"}
  ${wrapper "egrep" "-E"}
  ${wrapper "fgrep" "-F"}
''
