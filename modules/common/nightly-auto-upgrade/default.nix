{
  config,
  lib,
  pkgs,
  ...
}:
let
  githubPublicKey =
    let
      parts = builtins.filter builtins.isString (
        builtins.split " " (lib.removeSuffix "\n" (builtins.readFile ../../../secrets/git-ssh-key.pub))
      );
    in
    "${builtins.elemAt parts 0} ${builtins.elemAt parts 1}";
  githubEmail = "github@fullstackjack.io";

  allowedSigners = pkgs.writeText "allowed_signers" ''
    ${githubEmail} ${githubPublicKey}
  '';

  upgradeScript = pkgs.writeShellApplication {
    name = "nixos-auto-upgrade-run";
    runtimeInputs = [
      pkgs.git
      pkgs.openssh
    ];
    text = ''
      REPO_URL="git@github.com:fullykubed/nixos-config.git"
      HOSTNAME=$(hostname)

      CLONE_DIR=$(mktemp -d /tmp/nixos-auto-upgrade.XXXXXX)
      cleanup() { rm -rf "$CLONE_DIR"; }
      trap cleanup EXIT

      echo "Cloning $REPO_URL (branch main) to $CLONE_DIR..."
      git clone --depth 1 --branch main "$REPO_URL" "$CLONE_DIR"

      echo "Verifying commit signature..."
      if ! git -C "$CLONE_DIR" \
        -c gpg.format=ssh \
        -c gpg.ssh.allowedSignersFile="${allowedSigners}" \
        verify-commit HEAD 2>/dev/null; then
        echo "Signature verification failed — refusing to apply unsigned or untrusted commit"
        notify-if-away --force "NixOS Upgrade Blocked" "Commit signature verification failed on $HOSTNAME"
        exit 1
      fi
      echo "Signature verified"

      # Save current profile to detect activation failures vs build failures
      current_profile=$(readlink -f /nix/var/nix/profiles/system)

      echo "Running nixos-rebuild switch..."
      if nixos-rebuild switch --flake "$CLONE_DIR#$HOSTNAME" --accept-flake-config; then
        echo "Upgrade successful"
      else
        echo "Upgrade failed"

        # If the profile changed, activation failed — rollback
        new_profile=$(readlink -f /nix/var/nix/profiles/system)
        if [[ "$current_profile" != "$new_profile" ]]; then
          echo "Activation failure detected, rolling back..."
          nixos-rebuild switch --rollback || true
        fi

        notify-if-away --force "NixOS Upgrade Failed" "nixos-auto-upgrade failed on $HOSTNAME"
        exit 1
      fi
    '';
  };
in
{
  systemd.services.nixos-auto-upgrade = {
    description = "Nightly NixOS auto-upgrade";
    restartIfChanged = false;
    after = [ "agenix.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${upgradeScript}/bin/nixos-auto-upgrade-run";
    };
    environment = {
      GIT_SSH_COMMAND = "ssh -i ${config.age.secrets.git-ssh-key.path} -o IdentitiesOnly=yes";
    };
    path = [
      "/run/current-system/sw"
      "/nix/var/nix/profiles/default"
    ];
  };

  systemd.timers.nixos-auto-upgrade = {
    description = "Nightly NixOS auto-upgrade timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 01:00:00";
      Persistent = true;
      WakeSystem = true;
    };
  };
}
