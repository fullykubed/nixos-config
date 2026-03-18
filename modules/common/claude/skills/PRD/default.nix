{ pkgs, ... }:
let
  package = pkgs.stdenv.mkDerivation {
    pname = "claude-task-scripts";
    version = "1.0.0";

    src = ./scripts;

    buildInputs = [
      pkgs.bash
      pkgs.jaq
      pkgs.check-jsonschema
    ];

    installPhase = ''
      mkdir -p $out/bin $out/share/claude

      cp ${./schemas/tasks.schema.json} $out/share/claude/tasks.schema.json
      cp ${./schemas/research.schema.json} $out/share/claude/research.schema.json

      installScript() {
        local src="$1" name="$2"; shift 2
        substitute "$src" "$out/bin/claude-PRD-$name" \
          --replace "@jaq@" "${pkgs.jaq}/bin/jaq" \
          --replace "@check-jsonschema@" "${pkgs.check-jsonschema}/bin/check-jsonschema" \
          "$@"
        chmod +x "$out/bin/claude-PRD-$name"
      }

      installScript $src/task-status.sh             task-status
      installScript $src/update-task-status.sh      update-task-status
      installScript $src/list-prds.sh               list-prds
      installScript $src/research-status.sh         research-status
      installScript $src/list-prd-draft-tasks.sh    list-draft-tasks
      installScript $src/list-defined-tasks.sh      list-defined-tasks
      installScript $src/get-task.sh                get-task
      installScript $src/get-unanswered-research.sh get-unanswered-research

      installScript ${./hooks/validate-tasks.sh}    validate-tasks \
        --replace "@schema-path@" "$out/share/claude/tasks.schema.json"
      installScript ${./hooks/validate-research.sh} validate-research \
        --replace "@schema-path@" "$out/share/claude/research.schema.json"
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
          command = "${package}/bin/claude-PRD-validate-research";
        }
        {
          type = "command";
          command = "${package}/bin/claude-PRD-validate-tasks";
        }
      ];
    }
  ];
  homeFiles = {
    ".claude/skills/PRD" = {
      source = ./.;
      recursive = true;
    };
    ".claude/agents/prd-researcher.md" = {
      source = ./agents/prd-researcher.md;
    };
    ".claude/agents/prd-worker.md" = {
      source = ./agents/prd-worker.md;
    };
  };
}
