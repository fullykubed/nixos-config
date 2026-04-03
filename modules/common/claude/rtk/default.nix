{ pkgs, versions, ... }:
let
  package = pkgs.rustPlatform.buildRustPackage {
    pname = "rtk";
    version = versions.rtk;

    src = pkgs.fetchFromGitHub {
      owner = "rtk-ai";
      repo = "rtk";
      rev = versions.rtkRev;
      hash = versions.rtkSrcHash;
    };

    cargoHash = versions.rtkCargoHash;

    meta = with pkgs.lib; {
      description = "CLI proxy that reduces LLM token consumption by 60-90%";
      homepage = "https://github.com/rtk-ai/rtk";
      license = licenses.mit;
      mainProgram = "rtk";
    };
  };
in
{
  inherit package;

  hooks.PreToolUse = [
    {
      matcher = "Bash";
      hooks = [
        {
          type = "command";
          command = "${package}/bin/rtk hook";
          timeout = 5;
        }
      ];
    }
  ];

  homeFiles = {
    ".config/rtk/config.toml" = {
      text = ''
        [telemetry]
        enabled = false

        [tracking]
        enabled = true
        history_days = 90

        [display]
        colors = false
        emoji = false

        [tee]
        enabled = true
        mode = "failures"
        max_files = 20
      '';
    };
  };
}
