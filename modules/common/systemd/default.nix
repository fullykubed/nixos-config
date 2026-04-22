{
  pkgs,
  lib,
  config,
  ...
}:
{
  options.systemd.services = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        config.serviceConfig.RemainAfterExit = lib.mkDefault true;
        config.serviceConfig.LogFilterPatterns = lib.mkDefault [
          # High confidence — known vendor prefixes
          "~(?:AKIA|ASIA|ABIA|ACCA)[0-9A-Z]{16}"
          "~(?:ghp|gho|ghu|ghs|ghr)_[0-9a-zA-Z]{36}"
          "~-----BEGIN (?:RSA |DSA |EC |OPENSSH |PGP |ENCRYPTED )?PRIVATE KEY"
          "~eyJ[A-Za-z0-9_-]{10,}\\.eyJ[A-Za-z0-9_-]{10,}\\.[A-Za-z0-9_-]{10,}"
          "~AIza[0-9A-Za-z_-]{35}"
          "~xox[baprs]-[0-9a-zA-Z]{10,48}"
          "~AGE-SECRET-KEY-1[a-z0-9]{58}"
          "~hv[sbr]\\.[a-zA-Z0-9]{24,}"

          # Medium confidence — structural patterns
          "~(?i)(?:password|passwd|pwd)\\s*[=:]\\s*['\"]?[^\\s'\"]{8,}"
          "~(?i)(?:authorization|bearer)\\s*[:=]\\s*bearer\\s+[A-Za-z0-9._-]{20,}"
          "~[a-zA-Z]{3,10}://[^/\\s:@]{3,20}:[^/\\s:@]{3,20}@.{1,100}"
          "~(?i)(?:api[_-]?key|secret[_-]?key|access[_-]?token)\\s*[=:]\\s*['\"]?[a-zA-Z0-9_-]{20,}"
        ];
      }
    );
  };

  config = {
    # Services paired with a timer must not use RemainAfterExit=yes.
    # With RemainAfterExit the service stays "active (exited)" after completion,
    # so the next timer trigger is a no-op (already active).  Use mkOverride 999
    # so this beats the mkDefault true above but yields to any explicit override.
    systemd.services = lib.mapAttrs (_: _: {
      serviceConfig.RemainAfterExit = lib.mkOverride 999 false;
    }) config.systemd.timers;

    systemd.user.extraConfig = "DefaultLimitNOFILE=65536";

    environment.systemPackages = with pkgs; [
      systemd-manager-tui
    ];
  };
}
