{
  config,
  pkgs,
  lib,
  ...
}:
let
  # Build the notification hook script as a derivation
  claudeNotifyHook = pkgs.stdenv.mkDerivation {
    pname = "claude-notify-hook";
    version = "1.0.0";

    src = ./scripts;

    buildInputs = [
      pkgs.bash
      pkgs.jq
    ];

    installPhase = ''
      mkdir -p $out/bin

      # Substitute placeholders with actual paths in notify-hook script
      substitute $src/notify-hook.sh $out/bin/claude-notify-hook \
        --replace "@notify-send@" "${pkgs.libnotify}/bin/notify-send" \
        --replace "@jq@" "${pkgs.jq}/bin/jq" \
        --replace "@claude@" "${pkgs.unstable.claude-code}/bin/claude"

      # Copy and prepare the extract-conversation script
      substitute $src/extract-conversation.sh $out/bin/extract-conversation \
        --replace "jq" "${pkgs.jq}/bin/jq" \
        --replace "grep" "${pkgs.gnugrep}/bin/grep"

      # Update notify-hook to use the installed extract-conversation script
      substituteInPlace $out/bin/claude-notify-hook \
        --replace '"$script_dir/extract-conversation.sh"' '"${placeholder "out"}/bin/extract-conversation"'

      chmod +x $out/bin/claude-notify-hook
      chmod +x $out/bin/extract-conversation
    '';
  };

  # Path to the built notification hook
  notifyHook = "${claudeNotifyHook}/bin/claude-notify-hook";
in
{
  # Claude Code configuration and hooks
  home-manager.users.${config.username} = {
    # Claude Code settings with notification hooks
    home.file.".claude/settings.json".text = builtins.toJSON {
      includeCoAuthoredBy = false;
      hooks = {
        # Notification hook - triggers when Claude needs permission or is waiting
        Notification = [
          {
            matcher = ".*"; # Match all notifications
            hooks = [
              {
                type = "command";
                command = "${notifyHook}";
              }
            ];
          }
        ];

        # When main agent stops and might be waiting for input
        Stop = [
          {
            matcher = ".*";
            hooks = [
              {
                type = "command";
                command = "${notifyHook}";
              }
            ];
          }
        ];

        # When user submits a prompt - used to mark the Sway container
        UserPromptSubmit = [
          {
            matcher = ".*";
            hooks = [
              {
                type = "command";
                command = "${notifyHook}";
              }
            ];
          }
        ];
      };
    };
  };

  # Also make the script available in system packages for testing
  environment.systemPackages = with pkgs; [
    claudeNotifyHook
    unstable.claude-code
  ];
}
