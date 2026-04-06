{ pkgs, claude-code-sandboxed, ... }:
let
  package = pkgs.stdenv.mkDerivation {
    pname = "claude-surprises-scripts";
    version = "1.0.0";

    src = ./scripts;

    buildInputs = [
      pkgs.bash
      pkgs.jaq
    ];

    installPhase = ''
      mkdir -p $out/bin

      substitute $src/list.sh $out/bin/claude-Surprises-list \
        --replace "@jaq@" "${pkgs.jaq}/bin/jaq"
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
      pkgs.jaq
    ];

    installPhase = ''
      mkdir -p $out/bin
      substitute $src/surprise-hook.sh $out/bin/claude-surprise-hook \
        --replace "@jaq@" "${pkgs.jaq}/bin/jaq" \
        --replace "@claude@" "${claude-code-sandboxed}/bin/claude"
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
