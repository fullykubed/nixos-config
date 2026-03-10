{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.disableWakeupTriggers = lib.mkEnableOption "disable ACPI wakeup triggers before suspend";

  config = lib.mkIf config.disableWakeupTriggers {
    systemd.services.disable-wakeup-triggers = {
      description = "Disable wakeup triggers before suspend";
      wantedBy = [ "sleep.target" ];
      before = [ "sleep.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.bash}/bin/bash -c 'echo \"disabled\" | tee /sys/class/wakeup/*/device/physical_node/power/wakeup'";
      };
    };
  };
}
