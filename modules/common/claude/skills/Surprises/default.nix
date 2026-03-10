{ pkgs, nixpkgs-unstable, ... }:
let
  package = pkgs.stdenv.mkDerivation {
    pname = "claude-surprises-scripts";
    version = "1.0.0";

    src = ./scripts;

    buildInputs = [
      pkgs.bash
      pkgs.jq
    ];

    installPhase = ''
      mkdir -p $out/bin

      substitute $src/list.sh $out/bin/claude-Surprises-list \
        --replace "@jq@" "${pkgs.jq}/bin/jq"
      chmod +x $out/bin/claude-Surprises-list

      cp $src/get.sh $out/bin/claude-Surprises-get
      chmod +x $out/bin/claude-Surprises-get
    '';
  };

  hookPackage = pkgs.stdenv.mkDerivation {
    pname = "claude-surprise-hook";
    version = "1.0.0";

    src = ./hooks;

    buildInputs = [
      pkgs.bash
      pkgs.jq
    ];

    installPhase = ''
      mkdir -p $out/bin
      substitute $src/surprise-hook.sh $out/bin/claude-surprise-hook \
        --replace "@jq@" "${pkgs.jq}/bin/jq" \
        --replace "@claude@" "${nixpkgs-unstable.claude-code}/bin/claude"
      chmod +x $out/bin/claude-surprise-hook
    '';
  };
in
{
  inherit package hookPackage;
  homeFiles = {
    ".claude/skills/Surprises" = {
      source = ./.;
      recursive = true;
    };
    ".claude/agents/surprise-reviewer.md" = {
      source = ./agents/surprise-reviewer.md;
    };
    ".claude/agents/surprise-investigator.md" = {
      source = ./agents/surprise-investigator.md;
    };
  };
}
