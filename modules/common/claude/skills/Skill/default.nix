{ pkgs, extract-frontmatter, ... }:
let
  package = pkgs.stdenv.mkDerivation {
    pname = "claude-skill-scripts";
    version = "1.0.0";

    src = ./scripts;

    buildInputs = [
      pkgs.bash
      pkgs.jaq
      extract-frontmatter
    ];

    installPhase = ''
      mkdir -p $out/bin

      substitute $src/list-skills.sh "$out/bin/claude-Skill-list-skills" \
        --replace "@extract-frontmatter@" "${extract-frontmatter}/bin/extract-frontmatter" \
        --replace "@jaq@" "${pkgs.jaq}/bin/jaq"
      chmod +x "$out/bin/claude-Skill-list-skills"

      substitute $src/skill-info.sh "$out/bin/claude-Skill-skill-info" \
        --replace "@extract-frontmatter@" "${extract-frontmatter}/bin/extract-frontmatter" \
        --replace "@jaq@" "${pkgs.jaq}/bin/jaq"
      chmod +x "$out/bin/claude-Skill-skill-info"

      substitute ${./hooks/validate-skill.sh} "$out/bin/claude-Skill-validate-skill" \
        --replace "@extract-frontmatter@" "${extract-frontmatter}/bin/extract-frontmatter" \
        --replace "@jaq@" "${pkgs.jaq}/bin/jaq"
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
