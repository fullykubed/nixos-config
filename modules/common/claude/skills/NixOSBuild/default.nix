{ pkgs, homeDir, ... }:
let
  package = pkgs.stdenv.mkDerivation {
    pname = "claude-nixosbuild-scripts";
    version = "1.0.0";

    src = ./scripts;

    buildInputs = [ pkgs.bash ];

    installPhase = ''
      mkdir -p $out/bin
      for script in init-history record-attempt check-attempt list-attempts attempt-count; do
        cp "$src/$script.sh" "$out/bin/claude-NixOSBuild-$script"
        chmod +x "$out/bin/claude-NixOSBuild-$script"
      done
    '';
  };

  skillDocs = pkgs.stdenv.mkDerivation {
    pname = "claude-nixosbuild-docs";
    version = "1.0.0";

    src = ./.;

    installPhase = ''
      mkdir -p $out
      cp -r . $out/
      rm -f $out/default.nix
      find $out -name '*.md' -exec sed -i 's|@home@|${homeDir}|g' {} +
    '';
  };
in
{
  inherit package;
  homeFiles = {
    ".claude/skills/NixOSBuild" = {
      source = skillDocs;
      recursive = true;
    };
  };
}
