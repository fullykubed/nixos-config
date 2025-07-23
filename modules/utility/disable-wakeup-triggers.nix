# This disables waking up from any physyically attached devices
# to enforce needing to press the power button to resume from suspend
# This prevents issues with immediate resume after suspend due to issues with some connected devices

{ config, pkgs, ... }:
{
  systemd.services.disable-wakeup-triggers = {
    description = "Disable wakeup triggers before suspend";
    wantedBy = [ "sleep.target" ];
    before = [ "sleep.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c 'echo \"disabled\" | tee /sys/class/wakeup/*/device/physical_node/power/wakeup'";
    };
  };
}
