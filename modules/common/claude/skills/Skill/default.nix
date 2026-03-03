{ pkgs, ... }:
let
  package = pkgs.stdenv.mkDerivation {
    pname = "claude-skill-scripts";
    version = "1.0.0";

    src = ./scripts;

    buildInputs = [
      pkgs.bash
      pkgs.yq-go
      pkgs.jq
    ];

    installPhase = ''
      mkdir -p $out/bin

      substitute $src/list-skills.sh "$out/bin/claude-Skill-list-skills" \
        --replace "@yq@" "${pkgs.yq-go}/bin/yq" \
        --replace "@jq@" "${pkgs.jq}/bin/jq"
      chmod +x "$out/bin/claude-Skill-list-skills"

      substitute $src/skill-info.sh "$out/bin/claude-Skill-skill-info" \
        --replace "@yq@" "${pkgs.yq-go}/bin/yq" \
        --replace "@jq@" "${pkgs.jq}/bin/jq"
      chmod +x "$out/bin/claude-Skill-skill-info"

      substitute ${./hooks/validate-skill.sh} "$out/bin/claude-Skill-validate-skill" \
        --replace "@yq@" "${pkgs.yq-go}/bin/yq" \
        --replace "@jq@" "${pkgs.jq}/bin/jq"
      chmod +x "$out/bin/claude-Skill-validate-skill"
    '';
  };
in
{
  inherit package;
  hooks.PostToolUse = [
    {
      matcher = "Edit|Write";
      hooks = [
        {
          type = "command";
          command = "${package}/bin/claude-Skill-validate-skill";
        }
      ];
    }
  ];
  homeFiles = {
    ".claude/skills/Skill" = {
      source = ./.;
      recursive = true;
    };
  };
}
