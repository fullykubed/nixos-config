{
  buildSecureServiceConfig =
    overrides:
    {
      DynamicUser = true;
      NoNewPrivileges = "yes";
      UMask = "0077"; # R/W for user only
      PrivateDevices = "yes";
      DevicePolicy = "closed";
      DeviceAllow = "none";
      PrivateNetwork = "yes";
      PrivateUsers = "yes";
      PrivateTmp = "yes";
      IPAddressDeny = "any";
      MemoryDenyWriteExecute = "yes";
      ProtectKernelModules = "yes";
      ProtectKernelTunables = "yes";
      ProtectKernelLogs = "yes";
      ProtectControlGroups = "yes";
      ProtectProc = "noaccess";
      ProcSubset = "pid";
      ProtectHostname = "yes";
      ProtectClock = "yes";
      ProtectHome = "yes";
      RestrictNamespaces = "yes";
      RestrictRealtime = "yes";
      RestrictSUIDSGID = "yes";
      RestrictAddressFamilies = "none";
      LockPersonality = "yes";
      CapabilityBoundingSet = "";
      SystemCallArchitectures = "native";
      SystemCallFilter = [
        "~@clock"
        "~@debug"
        "~@mount"
        "~@module"
        "~@raw-io"
        "~@reboot"
        "~@swap"
        "~@privileged"
        "~@resources"
        "~@cpu-emulation"
        "~@obsolete"
      ];
    }
    // overrides;
}
