{ pkgs, ... }:
let
  package = pkgs.stdenv.mkDerivation {
    pname = "claude-github-scripts";
    version = "1.0.0";

    src = ./scripts;

    buildInputs = [
      pkgs.bash
      pkgs.gh
      pkgs.gitMinimal
      pkgs.jaq
      pkgs.check-jsonschema
    ];

    installPhase = ''
      mkdir -p $out/bin $out/share/claude

      cp ${./schemas/rca.schema.json} $out/share/claude/rca.schema.json

      substitute $src/repo-info.sh $out/bin/claude-GitHub-repo-info \
        --replace "@gh@" "${pkgs.gh}/bin/gh" \
        --replace "@git@" "${pkgs.gitMinimal}/bin/git" \
        --replace "@jaq@" "${pkgs.jaq}/bin/jaq"
      chmod +x $out/bin/claude-GitHub-repo-info

      substitute $src/file-issue.sh $out/bin/claude-GitHub-file-issue \
        --replace "@gh@" "${pkgs.gh}/bin/gh"
      chmod +x $out/bin/claude-GitHub-file-issue

      substitute ${./hooks/validate-rca.sh} $out/bin/claude-GitHub-validate-rca \
        --replace "@check-jsonschema@" "${pkgs.check-jsonschema}/bin/check-jsonschema" \
        --replace "@schema-path@" "$out/share/claude/rca.schema.json" \
        --replace "@jaq@" "${pkgs.jaq}/bin/jaq"
      chmod +x $out/bin/claude-GitHub-validate-rca
    '';
  };
in
{
  inherit package;
  homeFiles = {
    ".claude/skills/GitHub" = {
      source = ./.;
      recursive = true;
    };
    ".claude/agents/github-rca.md" = {
      source = ./agents/github-rca.md;
    };
  };
}
