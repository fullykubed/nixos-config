{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.croc-receive;
in
{
  options.services.croc-receive = {
    enable = lib.mkEnableOption "croc-based secret receiver";
    relayAddress = lib.mkOption {
      type = lib.types.str;
      description = "Address of the croc relay (host:port)";
      example = "localhost:19009";
    };
    localRelay = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether a local croc relay (croc.service) runs on this host";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.croc ];

    systemd.services.croc-receive = {
      description = "Receive and install secrets via croc";
      after = [
        "cloud-init.service"
        "network-online.target"
      ]
      ++ lib.optional cfg.localRelay "croc.service";
      wants = [
        "cloud-init.service"
        "network-online.target"
      ]
      ++ lib.optional cfg.localRelay "croc.service";
      before = [ "secrets-ready.target" ];
      wantedBy = [ "secrets-ready.target" ];
      environment.HOME = "/root";
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        TimeoutStartSec = 300;
        ExecStartPre = lib.mkIf cfg.localRelay "${pkgs.coreutils}/bin/sleep 60";
      };
      path = with pkgs; [
        croc
        coreutils
        bash
      ];
      script = ''
        relay="${cfg.relayAddress}"
        pass=$(cat /run/croc-relay-password)
        code=$(cat /run/croc-code)
        mkdir -p /run/croc-staging
        cd /run/croc-staging

        # Retry until the sender has created the room on the relay
        for attempt in $(seq 1 60); do
          if CROC_SECRET="$code" croc --yes --overwrite --relay "$relay" --pass "$pass"; then
            break
          fi
          echo "croc receive attempt $attempt failed, retrying in 5s..."
          sleep 5
        done

        if [ ! -f /run/croc-staging/install-secrets.sh ]; then
          echo "ERROR: install-secrets.sh not received after 60 attempts"
          exit 1
        fi

        bash /run/croc-staging/install-secrets.sh
      '';
    };

    systemd.targets.secrets-ready = {
      description = "All secrets have been received and installed";
      requires = [ "croc-receive.service" ];
      after = [ "croc-receive.service" ];
    };
  };
}
