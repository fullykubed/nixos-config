{
  config,
  pkgs,
  ...
}:
let
  # Whitelist of false positive CVEs
  whitelist = ./whitelist.toml;

  # Wrapper script that always uses the whitelist
  vulnix-wrapped = pkgs.writeShellScriptBin "vulnix" ''
    exec ${pkgs.vulnix}/bin/vulnix -w ${whitelist} "$@"
  '';
in
{
  # Make wrapped vulnix available system-wide (wrapper takes priority)
  environment.systemPackages = [ vulnix-wrapped ];

  # Shell alias for quick CVE scanning (runtime closure only)
  home-manager.users.${config.username}.home.shellAliases = {
    cve = "vulnix --system --closure";
  };

  systemd = {
    # Vulnix vulnerability scanner service
    services.vulnix-scanner = {
      description = "Vulnix CVE vulnerability scanner";
      serviceConfig = {
        Type = "oneshot";
        StandardOutput = "journal";
        StandardError = "journal";
        ExecStart = pkgs.writeShellScript "vulnix-scan" ''
          # Scan runtime closure only (excludes build-time dependencies)
          echo "Scanning system packages..."
          ${pkgs.vulnix}/bin/vulnix --system --closure -w ${whitelist}
          EXIT_CODE=$?

          if [ $EXIT_CODE -eq 2 ]; then
            echo "Vulnerabilities found!"
            exit 1
          elif [ $EXIT_CODE -ne 0 ]; then
            echo "Scan error occurred"
            exit 1
          fi

          echo "No vulnerabilities found"
          exit 0
        '';
      };
      environment = {
        LANG = "C.UTF-8";
      };
    };

    # Timer to run vulnerability scans daily
    timers.vulnix-scanner = {
      description = "Daily Vulnix vulnerability scan";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-* 02:00:00"; # 2 AM daily
        Persistent = true;
        WakeSystem = true;
      };
    };
  };
}
