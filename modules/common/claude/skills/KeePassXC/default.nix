{ pkgs, ... }:
let
  package = pkgs.stdenv.mkDerivation {
    pname = "claude-keepassxc-scripts";
    version = "1.0.0";

    src = ./scripts;

    buildInputs = [
      pkgs.bash
      pkgs.libsecret
      pkgs.gnugrep
      pkgs.jq
      pkgs.gawk
    ];

    installPhase = ''
      mkdir -p $out/bin

      substitute $src/search.sh $out/bin/claude-KeePassXC-search \
        --replace-fail "@grep@" "${pkgs.gnugrep}/bin/grep" \
        --replace-fail "@secret-tool@" "${pkgs.libsecret}/bin/secret-tool" \
        --replace-fail "@jq@" "${pkgs.jq}/bin/jq" \
        --replace-fail "@awk@" "${pkgs.gawk}/bin/awk"
      chmod +x $out/bin/claude-KeePassXC-search

      substitute $src/lookup.sh $out/bin/claude-KeePassXC-lookup \
        --replace-fail "@secret-tool@" "${pkgs.libsecret}/bin/secret-tool" \
        --replace-fail "@jq@" "${pkgs.jq}/bin/jq"
      chmod +x $out/bin/claude-KeePassXC-lookup
    '';
  };
in
{
  inherit package;
  homeFiles = {
    ".claude/skills/KeePassXC" = {
      source = ./.;
      recursive = true;
    };
  };
}
